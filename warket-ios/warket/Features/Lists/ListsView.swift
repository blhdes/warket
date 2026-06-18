import SwiftUI

/// User-selectable layout for the lists screen, persisted across launches.
enum ListLayout: String {
    case list, grid
}

/// The vault's lists with full CRUD: create/edit/delete, search (by list name or
/// contained asset name/ticker), tag filtering, drag-reorder, and a toggle
/// between a native List and the 2-column grid.
struct ListsView: View {
    let vaultHash: String
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toast

    @AppStorage("warket.listsLayout") private var layout: ListLayout = .list

    @State private var repo: VaultRepository
    @State private var lists: [ListWithAssetCount] = []
    @State private var assetIndex: [String: [AssetSearchRow]] = [:]
    @State private var phase: Phase = .loading

    @State private var search = ""
    @State private var activeTag: String?

    @State private var showingCreate = false
    @State private var editingList: ListWithAssetCount?
    @State private var pendingDelete: ListWithAssetCount?
    @State private var reorderTask: Task<Void, Never>?

    private enum Phase: Equatable { case loading, loaded, failed(String) }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    init(vaultHash: String) {
        self.vaultHash = vaultHash
        _repo = State(initialValue: VaultRepository(vaultHash: vaultHash))
    }

    var body: some View {
        ZStack {
            MarketPulseBackground()
            content
        }
        .navigationTitle("Lists")
        .searchable(text: $search, prompt: "Search lists & assets")
        .toolbar { toolbarContent }
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(for: VaultList.self) { list in
            AssetsView(list: list, repo: repo)
        }
        .sheet(isPresented: $showingCreate) {
            ListEditorSheet(mode: .create) { name, tags in
                await createList(name: name, tags: tags)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $editingList) { item in
            ListEditorSheet(mode: .edit(item.list)) { name, tags in
                await updateList(item, name: name, tags: tags)
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Delete \u{201C}\(pendingDelete?.list.name ?? "")\u{201D}?",
            isPresented: deletePresented,
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { item in
            Button("Delete list & \(item.assetCount) asset\(item.assetCount == 1 ? "" : "s")", role: .destructive) {
                Task { await delete(item) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView().tint(Theme.accent)

        case .failed(let message):
            stateMessage(icon: "exclamationmark.triangle", title: "Couldn't load lists", detail: message, tint: Theme.error)

        case .loaded:
            let tags = allTags
            let filtered = filteredLists
            VStack(spacing: 0) {
                if !tags.isEmpty { tagFilterBar(tags) }
                listOrGrid(filtered)
            }
        }
    }

    @ViewBuilder
    private func listOrGrid(_ filtered: [ListWithAssetCount]) -> some View {
        if filtered.isEmpty {
            if lists.isEmpty {
                stateMessage(icon: "tray", title: "No lists yet", detail: "Tap + to create your first list.", tint: Theme.textTertiary)
            } else {
                stateMessage(icon: "magnifyingglass", title: "No matches", detail: "Try a different search or tag.", tint: Theme.textTertiary)
            }
        } else if layout == .list {
            listLayout(filtered)
        } else {
            gridLayout(filtered)
        }
    }

    private func listLayout(_ filtered: [ListWithAssetCount]) -> some View {
        List {
            ForEach(filtered) { item in
                NavigationLink(value: item.list) {
                    ListRow(item: item)
                }
                .listRowBackground(glassRowBackground)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 30, bottom: 12, trailing: 22))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { pendingDelete = item } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button { editingList = item } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(Theme.accent)
                }
            }
            .onMove(perform: isFiltered ? nil : move)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// Inset glass slab used as each list row's background, so rows read as cards
    /// floating over the mesh with a hairline gap between them.
    private var glassRowBackground: some View {
        Color.clear
            .glassSurface(in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            .padding(.vertical, 3)
    }

    private func gridLayout(_ filtered: [ListWithAssetCount]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filtered) { item in
                    NavigationLink(value: item.list) {
                        ListCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { editingList = item } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) { pendingDelete = item } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .padding(16)
        }
    }

    private func tagFilterBar(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button {
                        activeTag = (activeTag == tag) ? nil : tag
                        Haptics.selection()
                    } label: {
                        TagPill(text: tag, selected: activeTag == tag)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if layout == .list {
            ToolbarItem(placement: .topBarLeading) { EditButton() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingCreate = true } label: { Image(systemName: "plus") }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Layout", selection: $layout) {
                    Label("List", systemImage: "list.bullet").tag(ListLayout.list)
                    Label("Grid", systemImage: "square.grid.2x2").tag(ListLayout.grid)
                }
                Divider()
                Button(role: .destructive) { session.signOut() } label: {
                    Label("Lock vault", systemImage: "lock.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func stateMessage(icon: String, title: String, detail: String, tint: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(tint)
            Text(title).font(.headline).foregroundStyle(Theme.textPrimary)
            Text(detail).font(.subheadline).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Derived

    private var isFiltered: Bool {
        !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || activeTag != nil
    }

    private var allTags: [String] {
        Set(lists.flatMap(\.list.tags)).sorted()
    }

    private var filteredLists: [ListWithAssetCount] {
        var result = lists
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { item in
                if item.list.name.lowercased().contains(query) { return true }
                let assets = assetIndex[item.list.id] ?? []
                return assets.contains {
                    $0.name.lowercased().contains(query) || $0.ticker.lowercased().contains(query)
                }
            }
        }
        if let tag = activeTag {
            result = result.filter { $0.list.tags.contains(tag) }
        }
        return result
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    // MARK: - Actions

    private func load() async {
        do {
            lists = try await repo.fetchLists()
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }
        if let rows = try? await repo.fetchAssetIndex(listIds: lists.map(\.list.id)) {
            assetIndex = Dictionary(grouping: rows, by: \.listId)
        }
    }

    private func createList(name: String, tags: [String]) async -> Bool {
        do {
            try await repo.createList(name: name, tags: tags, position: lists.count)
            Haptics.success()
            toast.show("List created", .success)
            await load()
            return true
        } catch {
            Haptics.error()
            toast.show(error.localizedDescription, .error)
            return false
        }
    }

    private func updateList(_ item: ListWithAssetCount, name: String, tags: [String]) async -> Bool {
        do {
            try await repo.updateList(id: item.list.id, name: name, tags: tags)
            Haptics.success()
            toast.show("List updated", .success)
            await load()
            return true
        } catch {
            Haptics.error()
            toast.show(error.localizedDescription, .error)
            return false
        }
    }

    private func delete(_ item: ListWithAssetCount) async {
        do {
            try await repo.deleteList(id: item.list.id)
            Haptics.success()
            toast.show("List deleted", .success)
            pendingDelete = nil
            await load()
        } catch {
            Haptics.error()
            toast.show(error.localizedDescription, .error)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        lists.move(fromOffsets: source, toOffset: destination)
        Haptics.impact(.light)
        let changes = lists.enumerated().map { PositionChange(id: $0.element.list.id, position: $0.offset) }
        reorderTask?.cancel()
        reorderTask = Task {
            do {
                try await repo.updatePositions(table: "lists", changes: changes)
            } catch {
                if !Task.isCancelled { toast.show(error.localizedDescription, .error) }
            }
        }
    }
}

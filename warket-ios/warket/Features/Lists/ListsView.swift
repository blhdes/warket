import os
import SwiftUI

/// User-selectable layout for the lists screen, persisted across launches.
enum ListLayout: String {
    case list, grid
}

/// The vault's lists with full CRUD: create/edit/delete, search (by list name or
/// contained asset name/ticker), tag filtering, drag-reorder, and a toggle
/// between a native List and the 2-column grid.
struct ListsView: View {
    let access: VaultAccess
    @Environment(Session.self) private var session

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

    @State private var transferRequest: TransferRequest?
    @State private var accountPrompt: AccountPrompt?
    @State private var alert: ScreenAlert?

    private enum Phase: Equatable { case loading, loaded, failed(String) }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    init(access: VaultAccess) {
        self.access = access
        _repo = State(initialValue: VaultRepository(access: access))
    }

    var body: some View {
        content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Lists")
        .readOnlySubtitle(readOnly)
        .searchable(text: $search, prompt: "Search lists & assets")
        .toolbar { toolbarContent }
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(for: VaultList.self) { list in
            AssetsView(list: list, repo: repo, readOnly: readOnly)
        }
        .sheet(isPresented: $showingCreate) {
            ListEditorSheet(mode: .create) { name, tags in
                try await createList(name: name, tags: tags)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $editingList) { item in
            ListEditorSheet(mode: .edit(item.list)) { name, tags in
                try await updateList(item, name: name, tags: tags)
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
        .vaultTransferActions($transferRequest, repo: repo) { await load() }
        .vaultAccountActions($accountPrompt, repo: repo)
        .screenAlert($alert)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView()

        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load Lists", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    phase = .loading
                    Task { await load() }
                }
                .buttonStyle(.bordered)
            }

        case .loaded:
            listOrGrid(filteredLists)
        }
    }

    @ViewBuilder
    private func listOrGrid(_ filtered: [ListWithAssetCount]) -> some View {
        if filtered.isEmpty {
            if lists.isEmpty {
                ContentUnavailableView("No Lists Yet", systemImage: "tray",
                                       description: Text("Tap + to create your first list."))
            } else {
                ContentUnavailableView {
                    Label("No Matches", systemImage: "magnifyingglass")
                } description: {
                    Text("Try a different search or tag.")
                } actions: {
                    Button("Show All") { search = ""; activeTag = nil }
                }
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
                .swipeActions(edge: .trailing) {
                    if !readOnly {
                        Button(role: .destructive) { pendingDelete = item } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { editingList = item } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.accentColor)
                    }
                }
            }
            .onMove(perform: (readOnly || isFiltered) ? nil : move)
        }
        .listStyle(.insetGrouped)
    }

    private func gridLayout(_ filtered: [ListWithAssetCount]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filtered) { item in
                    let card = NavigationLink(value: item.list) {
                        ListCard(item: item)
                    }
                    .buttonStyle(.plain)

                    if readOnly {
                        card
                    } else {
                        card.contextMenu {
                            Button { editingList = item } label: { Label("Edit", systemImage: "pencil") }
                            Button(role: .destructive) { pendingDelete = item } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !readOnly && layout == .list {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        if !allTags.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                TagFilterMenu(tags: allTags, selection: $activeTag)
            }
        }
        ToolbarItem(placement: .topBarTrailing) { moreMenu }

        DefaultToolbarItem(kind: .search, placement: .bottomBar)
        if !readOnly {
            ToolbarSpacer(.fixed, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                Button("New List", systemImage: "plus") { showingCreate = true }
            }
        }
    }

    private var moreMenu: some View {
        Menu {
            Picker("Layout", selection: $layout) {
                Label("List", systemImage: "list.bullet").tag(ListLayout.list)
                Label("Grid", systemImage: "square.grid.2x2").tag(ListLayout.grid)
            }
            Divider()
            Button { transferRequest = .export } label: {
                Label("Export Vault", systemImage: "square.and.arrow.up")
            }
            if !readOnly {
                Button { transferRequest = .importFile } label: {
                    Label("Import Vault", systemImage: "square.and.arrow.down")
                }
                Button { transferRequest = .share } label: {
                    Label("Share Read-Only Key", systemImage: "person.crop.circle.badge.plus")
                }
            }
            Divider()
            Button { accountPrompt = .about } label: {
                Label("About", systemImage: "info.circle")
            }
            if readOnly {
                Button(role: .destructive) { session.signOut() } label: {
                    Label("Exit Shared Vault", systemImage: "xmark.circle")
                }
            } else {
                Button(role: .destructive) { accountPrompt = .lock } label: {
                    Label("Lock Vault", systemImage: "lock.fill")
                }
                Button(role: .destructive) { accountPrompt = .deleteVault } label: {
                    Label("Delete Vault\u{2026}", systemImage: "trash")
                }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
    }

    // MARK: - Derived

    private var readOnly: Bool { access.isReadOnly }

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
        } catch is CancellationError {
            return // the screen closed or a newer load replaced this one
        } catch {
            phase = .failed(error.userMessage)
            return
        }
        // Search by asset name still works without the index, so a failure here only logs.
        do {
            let rows = try await repo.fetchAssetIndex()
            assetIndex = Dictionary(grouping: rows, by: \.listId)
        } catch {
            Logger.api.error("Search index failed to load: \(error.localizedDescription)")
        }
    }

    /// Throws so the editor sheet can stay open and show the error.
    private func createList(name: String, tags: [String]) async throws {
        do {
            try await repo.createList(name: name, tags: tags)
        } catch {
            Haptics.error()
            throw error
        }
        Haptics.success()
        await load()
    }

    private func updateList(_ item: ListWithAssetCount, name: String, tags: [String]) async throws {
        do {
            try await repo.updateList(id: item.list.id, name: name, tags: tags)
        } catch {
            Haptics.error()
            throw error
        }
        Haptics.success()
        await load()
    }

    private func delete(_ item: ListWithAssetCount) async {
        do {
            try await repo.deleteList(id: item.list.id)
            Haptics.success()
            pendingDelete = nil
            await load()
        } catch {
            Haptics.error()
            alert = ScreenAlert(title: "Couldn't Delete List", message: error.userMessage)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        lists.move(fromOffsets: source, toOffset: destination)
        Haptics.impact(.light)
        let ids = lists.map(\.list.id)
        reorderTask?.cancel()
        reorderTask = Task {
            do {
                try await repo.reorderLists(ids: ids)
            } catch {
                // Cancelled means a newer drag replaced this one and will save the order itself.
                guard !Task.isCancelled else { return }
                Haptics.error()
                alert = ScreenAlert(title: "Couldn't Save the Order", message: error.userMessage)
                await load() // nothing was saved, so show the server's order again
            }
        }
    }
}

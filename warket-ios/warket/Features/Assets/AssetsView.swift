import SwiftUI

/// Assets in one list, as a native List with full CRUD: add/edit/delete,
/// search, tag filtering, and drag-reorder.
struct AssetsView: View {
    let list: VaultList
    let repo: VaultRepository
    @Environment(ToastCenter.self) private var toast

    @State private var assets: [Asset] = []
    @State private var phase: Phase = .loading
    @State private var search = ""
    @State private var activeTag: String?

    @State private var showingCreate = false
    @State private var editing: Asset?
    @State private var pendingDelete: Asset?
    @State private var reloadToken = UUID()
    @State private var reorderTask: Task<Void, Never>?

    private enum Phase: Equatable { case loading, loaded, failed(String) }

    var body: some View {
        ZStack {
            Theme.surface0.ignoresSafeArea()
            content
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Search assets")
        .toolbar { toolbarContent }
        .task(id: reloadToken) { await load() }
        .refreshable { await load() }
        .navigationDestination(for: Asset.self) { asset in
            AssetDetailView(asset: asset, repo: repo) { reloadToken = UUID() }
        }
        .sheet(isPresented: $showingCreate) {
            AssetEditorSheet(mode: .create) { draft in await createAsset(draft) }
        }
        .sheet(item: $editing) { asset in
            AssetEditorSheet(mode: .edit(asset)) { draft in await updateAsset(asset, draft) }
        }
        .confirmationDialog(
            "Delete \u{201C}\(pendingDelete?.name ?? "")\u{201D}?",
            isPresented: deletePresented,
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { asset in
            Button("Delete asset", role: .destructive) { Task { await delete(asset) } }
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
            stateMessage(icon: "exclamationmark.triangle", title: "Couldn't load assets", detail: message, tint: Theme.error)

        case .loaded:
            let tags = allTags
            let filtered = filteredAssets
            VStack(spacing: 0) {
                if !tags.isEmpty { tagFilterBar(tags) }
                if filtered.isEmpty {
                    emptyState
                } else {
                    assetList(filtered)
                }
            }
        }
    }

    private func assetList(_ filtered: [Asset]) -> some View {
        List {
            ForEach(filtered) { asset in
                NavigationLink(value: asset) {
                    AssetRow(asset: asset)
                }
                .listRowBackground(Theme.surface1)
                .listRowSeparatorTint(Theme.borderDefault)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { pendingDelete = asset } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button { editing = asset } label: {
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

    @ViewBuilder
    private var emptyState: some View {
        if assets.isEmpty {
            stateMessage(icon: "tray", title: "No assets yet", detail: "Tap + to add your first asset.", tint: Theme.textTertiary)
        } else {
            stateMessage(icon: "magnifyingglass", title: "No matches", detail: "Try a different search or tag.", tint: Theme.textTertiary)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { EditButton() }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingCreate = true } label: { Image(systemName: "plus") }
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
        Set(assets.flatMap(\.tags)).sorted()
    }

    private var filteredAssets: [Asset] {
        var result = assets
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter {
                $0.name.lowercased().contains(query)
                    || $0.ticker.lowercased().contains(query)
                    || $0.summary.lowercased().contains(query)
            }
        }
        if let tag = activeTag {
            result = result.filter { $0.tags.contains(tag) }
        }
        return result
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    // MARK: - Actions

    private func load() async {
        do {
            assets = try await repo.fetchAssets(listId: list.id)
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func createAsset(_ draft: AssetDraft) async -> Bool {
        do {
            try await repo.addAsset(
                listId: list.id,
                name: draft.name,
                ticker: draft.ticker,
                summary: draft.summary,
                description: draft.description,
                tags: draft.tags,
                resources: draft.resources,
                imageUrl: draft.imageUrl.isEmpty ? nil : draft.imageUrl,
                position: assets.count
            )
            Haptics.success()
            toast.show("Asset added", .success)
            await load()
            return true
        } catch {
            Haptics.error()
            toast.show(error.localizedDescription, .error)
            return false
        }
    }

    private func updateAsset(_ original: Asset, _ draft: AssetDraft) async -> Bool {
        do {
            try await repo.updateAsset(id: original.id, fields: AssetUpdate(
                name: draft.name, ticker: draft.ticker, summary: draft.summary,
                description: draft.description, tags: draft.tags,
                resources: draft.resources, image_url: draft.imageUrl
            ))
            Haptics.success()
            toast.show("Asset updated", .success)
            await load()
            return true
        } catch {
            Haptics.error()
            toast.show(error.localizedDescription, .error)
            return false
        }
    }

    private func delete(_ asset: Asset) async {
        do {
            try await repo.deleteAsset(id: asset.id)
            Haptics.success()
            toast.show("Asset deleted", .success)
            pendingDelete = nil
            await load()
        } catch {
            Haptics.error()
            toast.show(error.localizedDescription, .error)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        assets.move(fromOffsets: source, toOffset: destination)
        Haptics.impact(.light)
        let changes = assets.enumerated().map { PositionChange(id: $0.element.id, position: $0.offset) }
        reorderTask?.cancel()
        reorderTask = Task {
            do {
                try await repo.updatePositions(table: "assets", changes: changes)
            } catch {
                if !Task.isCancelled { toast.show(error.localizedDescription, .error) }
            }
        }
    }
}

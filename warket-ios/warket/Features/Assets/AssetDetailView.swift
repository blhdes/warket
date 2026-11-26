import SwiftUI

/// Asset detail: name/ticker, image, summary, markdown notes, tags, and tappable
/// resource links, as grouped list sections. Edit/Delete live in the toolbar menu.
struct AssetDetailView: View {
    @State private var asset: Asset
    let repo: VaultRepository
    let readOnly: Bool
    let onChanged: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var faviconSize: CGFloat = 20

    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var alert: ScreenAlert?

    init(asset: Asset, repo: VaultRepository, readOnly: Bool = false, onChanged: @escaping () -> Void) {
        _asset = State(initialValue: asset)
        self.repo = repo
        self.readOnly = readOnly
        self.onChanged = onChanged
    }

    var body: some View {
        List {
            Section {
                header
                    .listRowBackground(Color.clear)
            }
            if let raw = asset.imageUrl, !raw.isEmpty, let url = URL(string: raw) {
                Section {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            Color.clear
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .accessibilityHidden(true)
                }
            }
            if !asset.summary.isEmpty {
                Section { Text(asset.summary) }
            }
            if !asset.description.isEmpty {
                Section("Notes") { MarkdownText(asset.description) }
            }
            if !asset.tags.isEmpty {
                Section("Tags") {
                    FlowLayout(spacing: 8) {
                        ForEach(asset.tags, id: \.self) { tag in
                            Text("#\(tag)").foregroundStyle(.tint)
                        }
                    }
                }
            }
            if !asset.resources.isEmpty {
                Section("Resources") {
                    ForEach(Array(asset.resources.enumerated()), id: \.offset) { _, resource in
                        resourceRow(resource)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !readOnly {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) { confirmingDelete = true } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis")
                    }
                }
            }
        }
        .sheet(isPresented: $editing) {
            AssetEditorSheet(mode: .edit(asset)) { draft in try await applyEdit(draft) }
        }
        .confirmationDialog(
            "Delete \u{201C}\(asset.name)\u{201D}?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete asset", role: .destructive) { Task { await deleteAsset() } }
            Button("Cancel", role: .cancel) {}
        }
        .screenAlert($alert)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(asset.name)
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
            if !asset.ticker.isEmpty {
                Text(asset.ticker.uppercased())
                    .font(.headline)
                    .monospaced()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func resourceRow(_ resource: Resource) -> some View {
        Button {
            guard let url = URL(string: resource.url), url.isWebLink else {
                alert = ScreenAlert(title: "Can't Open Link",
                                    message: "Only web links (http or https) can be opened.")
                return
            }
            openURL(url, prefersInApp: true)
        } label: {
            HStack(spacing: 12) {
                favicon(resource.favicon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(resource.title.isEmpty ? resource.url : resource.title)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(resource.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: Helpers

    private func favicon(_ raw: String) -> some View {
        Group {
            if !raw.isEmpty, let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        faviconPlaceholder
                    }
                }
            } else {
                faviconPlaceholder
            }
        }
        .frame(width: faviconSize, height: faviconSize)
        .accessibilityHidden(true)
    }

    private var faviconPlaceholder: some View {
        Image(systemName: "link").font(.caption).foregroundStyle(.secondary)
    }

    // MARK: Actions

    /// Throws so the editor sheet can stay open and show the error.
    private func applyEdit(_ draft: AssetDraft) async throws {
        do {
            // The server tidies input (uppercase ticker, lowercase tags), so show what it saved.
            asset = try await repo.updateAsset(id: asset.id, fields: AssetUpdate(
                name: draft.name, ticker: draft.ticker, summary: draft.summary,
                description: draft.description, tags: draft.tags,
                resources: draft.resources, image_url: draft.imageUrl
            ))
        } catch {
            Haptics.error()
            throw error
        }
        Haptics.success()
        onChanged()
    }

    private func deleteAsset() async {
        do {
            try await repo.deleteAsset(id: asset.id)
            Haptics.success()
            onChanged()
            dismiss()
        } catch {
            Haptics.error()
            alert = ScreenAlert(title: "Couldn't Delete Asset", message: error.userMessage)
        }
    }
}

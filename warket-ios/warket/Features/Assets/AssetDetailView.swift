import SwiftUI

/// Asset detail: image, name/ticker, summary, markdown notes, tags, and tappable
/// resource links. Edit/Delete live in the toolbar menu.
struct AssetDetailView: View {
    @State private var asset: Asset
    let repo: VaultRepository
    let readOnly: Bool
    let onChanged: () -> Void

    @Environment(ToastCenter.self) private var toast
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @State private var editing = false
    @State private var confirmingDelete = false

    init(asset: Asset, repo: VaultRepository, readOnly: Bool = false, onChanged: @escaping () -> Void) {
        _asset = State(initialValue: asset)
        self.repo = repo
        self.readOnly = readOnly
        self.onChanged = onChanged
    }

    var body: some View {
        ZStack {
            MarketPulseBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if !asset.summary.isEmpty { summary }
                    if !asset.description.isEmpty { notes }
                    if !asset.tags.isEmpty { tags }
                    if !asset.resources.isEmpty { resources }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $editing) {
            AssetEditorSheet(mode: .edit(asset)) { draft in await applyEdit(draft) }
        }
        .confirmationDialog(
            "Delete \u{201C}\(asset.name)\u{201D}?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete asset", role: .destructive) { Task { await deleteAsset() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let raw = asset.imageUrl, !raw.isEmpty, let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .glassSurface(in: RoundedRectangle(cornerRadius: 14))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(asset.name)
                    .font(.serif(34, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.textPrimary)
                if !asset.ticker.isEmpty {
                    Text(asset.ticker.uppercased())
                        .font(.mono(17, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private var summary: some View {
        Text(asset.summary)
            .font(.body)
            .foregroundStyle(Theme.textSecondary)
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Notes")
            MarkdownText(asset.description)
        }
    }

    private var tags: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Tags")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(asset.tags, id: \.self) { TagPill(text: $0) }
                }
            }
        }
    }

    private var resources: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Resources")
            ForEach(Array(asset.resources.enumerated()), id: \.offset) { _, resource in
                resourceRow(resource)
            }
        }
    }

    private func resourceRow(_ resource: Resource) -> some View {
        Button {
            if let url = URL(string: resource.url) { openURL(url) }
        } label: {
            HStack(spacing: 12) {
                favicon(resource.favicon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(resource.title.isEmpty ? resource.url : resource.title)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(resource.url)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(12)
            .glassSurface(in: RoundedRectangle(cornerRadius: 12), interactive: true)
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private func favicon(_ raw: String) -> some View {
        Group {
            if !raw.isEmpty, let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        Image(systemName: "link").font(.caption).foregroundStyle(Theme.textTertiary)
                    }
                }
            } else {
                Image(systemName: "link").font(.caption).foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: 20, height: 20)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(Theme.textTertiary)
    }

    // MARK: Actions

    private func applyEdit(_ draft: AssetDraft) async -> Bool {
        do {
            try await repo.updateAsset(id: asset.id, fields: AssetUpdate(
                name: draft.name, ticker: draft.ticker, summary: draft.summary,
                description: draft.description, tags: draft.tags,
                resources: draft.resources, image_url: draft.imageUrl
            ))
            asset.name = draft.name
            asset.ticker = draft.ticker
            asset.summary = draft.summary
            asset.description = draft.description
            asset.tags = draft.tags
            asset.resources = draft.resources
            asset.imageUrl = draft.imageUrl
            Haptics.success()
            toast.show("Asset updated", .success)
            onChanged()
            return true
        } catch {
            Haptics.error()
            toast.show(error.localizedDescription, .error)
            return false
        }
    }

    private func deleteAsset() async {
        do {
            try await repo.deleteAsset(id: asset.id)
            Haptics.success()
            toast.show("Asset deleted", .success)
            onChanged()
            dismiss()
        } catch {
            Haptics.error()
            toast.show(error.localizedDescription, .error)
        }
    }
}

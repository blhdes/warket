import SwiftUI

/// The editable fields of an asset, passed from the editor back to the caller,
/// which performs the actual Supabase create/update.
struct AssetDraft {
    var name: String
    var ticker: String
    var summary: String
    var description: String
    var tags: [String]
    var resources: [Resource]
    var imageUrl: String
}

/// Create or edit an asset: name, ticker, summary (≤250), markdown notes with a
/// live preview, tags, image URL, and resources (add/remove/reorder).
struct AssetEditorSheet: View {
    enum Mode {
        case create
        case edit(Asset)
    }

    let mode: Mode
    let onSave: (AssetDraft) async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var ticker: String
    @State private var summary: String
    @State private var description: String
    @State private var imageUrl: String
    @State private var tags: [String]
    @State private var resources: [EditableResource]
    @State private var notesMode: NotesMode = .write
    @State private var showingAddResource = false
    @State private var isSaving = false

    private enum NotesMode: String, CaseIterable {
        case write = "Write"
        case preview = "Preview"
    }

    /// Resources need stable identity while being reordered/deleted in the editor.
    private struct EditableResource: Identifiable, Equatable {
        let id = UUID()
        var resource: Resource
    }

    init(mode: Mode, onSave: @escaping (AssetDraft) async -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _ticker = State(initialValue: "")
            _summary = State(initialValue: "")
            _description = State(initialValue: "")
            _imageUrl = State(initialValue: "")
            _tags = State(initialValue: [])
            _resources = State(initialValue: [])
        case .edit(let asset):
            _name = State(initialValue: asset.name)
            _ticker = State(initialValue: asset.ticker)
            _summary = State(initialValue: asset.summary)
            _description = State(initialValue: asset.description)
            _imageUrl = State(initialValue: asset.imageUrl ?? "")
            _tags = State(initialValue: asset.tags)
            _resources = State(initialValue: asset.resources.map { EditableResource(resource: $0) })
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                summarySection
                notesSection
                tagsSection
                imageSection
                resourcesSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.surface0)
            .navigationTitle(isCreate ? "New Asset" : "Edit Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(trimmedName.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showingAddResource) {
                AddResourceSheet { resources.append(EditableResource(resource: $0)) }
            }
        }
    }

    // MARK: Sections

    private var detailsSection: some View {
        Section("Details") {
            TextField("Name", text: $name)
            TextField("Ticker", text: $ticker)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        }
    }

    private var summarySection: some View {
        Section {
            TextField("Short summary", text: $summary, axis: .vertical)
                .lineLimit(2...4)
                .onChange(of: summary) { _, value in
                    if value.count > 250 { summary = String(value.prefix(250)) }
                }
        } header: {
            Text("Summary")
        } footer: {
            Text("\(summary.count)/250")
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            Picker("Mode", selection: $notesMode) {
                ForEach(NotesMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if notesMode == .write {
                TextField("Markdown supported…", text: $description, axis: .vertical)
                    .lineLimit(5...14)
                    .font(.mono(15, relativeTo: .body))
            } else if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Nothing to preview")
                    .foregroundStyle(Theme.textTertiary)
            } else {
                MarkdownText(description)
            }
        }
    }

    private var tagsSection: some View {
        Section("Tags") {
            TagEditor(tags: $tags)
        }
    }

    private var imageSection: some View {
        Section("Image URL") {
            TextField("https://…", text: $imageUrl)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            if !imageUrl.isEmpty, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            }
        }
    }

    private var resourcesSection: some View {
        Section {
            ForEach($resources) { $item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.resource.title.isEmpty ? item.resource.url : item.resource.title)
                        .lineLimit(1)
                        .foregroundStyle(Theme.textPrimary)
                    Text(item.resource.url)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }
            .onDelete { resources.remove(atOffsets: $0) }
            .onMove { resources.move(fromOffsets: $0, toOffset: $1) }

            Button { showingAddResource = true } label: {
                Label("Add resource", systemImage: "plus")
            }
        } header: {
            HStack {
                Text("Resources")
                Spacer()
                if !resources.isEmpty { EditButton() }
            }
        }
    }

    // MARK: Helpers

    private var isCreate: Bool {
        if case .create = mode { return true }
        return false
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        isSaving = true
        let draft = AssetDraft(
            name: trimmedName,
            ticker: ticker.trimmingCharacters(in: .whitespaces),
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            tags: tags,
            resources: resources.map(\.resource),
            imageUrl: imageUrl.trimmingCharacters(in: .whitespaces)
        )
        await onSave(draft)
        dismiss()
    }
}

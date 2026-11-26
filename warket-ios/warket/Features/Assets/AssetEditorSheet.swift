import SwiftUI

/// The editable fields of an asset, passed from the editor back to the caller,
/// which performs the actual server create/update.
struct AssetDraft: Equatable {
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
    /// Throws when the server refuses the change. The sheet stays open, keeps the input and shows why.
    let onSave: (AssetDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    /// What the fields held when the sheet opened, to tell whether anything changed.
    private let original: AssetDraft

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
    @State private var saveError: ScreenAlert?

    private enum NotesMode: String, CaseIterable {
        case write = "Write"
        case preview = "Preview"
    }

    /// Resources need stable identity while being reordered/deleted in the editor.
    private struct EditableResource: Identifiable, Equatable {
        let id = UUID()
        var resource: Resource
    }

    init(mode: Mode, onSave: @escaping (AssetDraft) async throws -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            original = AssetDraft(name: "", ticker: "", summary: "", description: "",
                                  tags: [], resources: [], imageUrl: "")
        case .edit(let asset):
            original = AssetDraft(name: asset.name, ticker: asset.ticker, summary: asset.summary,
                                  description: asset.description, tags: asset.tags,
                                  resources: asset.resources, imageUrl: asset.imageUrl ?? "")
        }
        _name = State(initialValue: original.name)
        _ticker = State(initialValue: original.ticker)
        _summary = State(initialValue: original.summary)
        _description = State(initialValue: original.description)
        _imageUrl = State(initialValue: original.imageUrl)
        _tags = State(initialValue: original.tags)
        _resources = State(initialValue: original.resources.map { EditableResource(resource: $0) })
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
            .navigationTitle(isCreate ? "New Asset" : "Edit Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { Task { await save() } }
                        .disabled(trimmedName.isEmpty || isSaving)
                        .accessibilityLabel("Save")
                }
            }
            .screenAlert($saveError)
            .sheet(isPresented: $showingAddResource) {
                AddResourceSheet { resources.append(EditableResource(resource: $0)) }
            }
        }
        .confirmDiscard(when: hasChanges)
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
                    let clamped = Asset.clampSummary(value)
                    if clamped != value { summary = clamped }
                }
        } header: {
            Text("Summary")
        } footer: {
            Text("\(summary.unicodeScalars.count)/\(Asset.summaryLimit)")
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(summary.unicodeScalars.count)))
                .animation(.snappy, value: summary.unicodeScalars.count)
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
                    .fontDesign(.monospaced)
            } else if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Nothing to preview")
                    .foregroundStyle(.secondary)
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
                    Text(item.resource.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .onDelete { resources.remove(atOffsets: $0) }
            .onMove { resources.move(fromOffsets: $0, toOffset: $1) }

            Button { showingAddResource = true } label: {
                Label("Add Resource", systemImage: "plus")
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

    /// The fields as they would be saved (trimmed), so stray spaces don't count as changes.
    private var draft: AssetDraft {
        AssetDraft(
            name: trimmedName,
            ticker: ticker.trimmingCharacters(in: .whitespaces),
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            tags: tags,
            resources: resources.map(\.resource),
            imageUrl: imageUrl.trimmingCharacters(in: .whitespaces)
        )
    }

    private var hasChanges: Bool { draft != original }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await onSave(draft)
            dismiss()
        } catch {
            saveError = ScreenAlert(title: "Couldn't Save", message: error.userMessage)
        }
    }
}

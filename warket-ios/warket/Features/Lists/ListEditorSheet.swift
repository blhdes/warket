import SwiftUI

/// Create or edit a list (name + tags). The parent supplies an async `onSave`
/// closure that performs the actual server write, then this sheet dismisses.
struct ListEditorSheet: View {
    enum Mode {
        case create
        case edit(VaultList)
    }

    let mode: Mode
    /// Throws when the server refuses the change. The sheet stays open, keeps the input and shows why.
    let onSave: (_ name: String, _ tags: [String]) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    private let originalName: String
    private let originalTags: [String]
    @State private var name: String
    @State private var tags: [String]
    @State private var isSaving = false
    @State private var saveError: ScreenAlert?

    init(mode: Mode, onSave: @escaping (String, [String]) async throws -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            originalName = ""
            originalTags = []
        case .edit(let list):
            originalName = list.name
            originalTags = list.tags
        }
        _name = State(initialValue: originalName)
        _tags = State(initialValue: originalTags)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("List name", text: $name)
                }
                Section("Tags") {
                    TagEditor(tags: $tags)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(isCreate ? "New List" : "Edit List")
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
        }
        .confirmDiscard(when: hasChanges)
    }

    private var isCreate: Bool {
        if case .create = mode { return true }
        return false
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        trimmedName != originalName || tags != originalTags
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await onSave(trimmedName, tags)
            dismiss()
        } catch {
            saveError = ScreenAlert(title: "Couldn't Save", message: error.userMessage)
        }
    }
}

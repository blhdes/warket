import SwiftUI

/// Create or edit a list (name + tags). The parent supplies an async `onSave`
/// closure that performs the actual Supabase write, then this sheet dismisses.
struct ListEditorSheet: View {
    enum Mode {
        case create
        case edit(VaultList)
    }

    let mode: Mode
    let onSave: (_ name: String, _ tags: [String]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var tags: [String]
    @State private var isSaving = false

    init(mode: Mode, onSave: @escaping (String, [String]) async -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _tags = State(initialValue: [])
        case .edit(let list):
            _name = State(initialValue: list.name)
            _tags = State(initialValue: list.tags)
        }
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
            .scrollContentBackground(.hidden)
            .background(Theme.surface0)
            .navigationTitle(isCreate ? "New List" : "Edit List")
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
        }
    }

    private var isCreate: Bool {
        if case .create = mode { return true }
        return false
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        isSaving = true
        await onSave(trimmedName, tags)
        dismiss()
    }
}

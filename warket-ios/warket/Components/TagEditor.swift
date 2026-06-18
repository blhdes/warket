import SwiftUI

/// Editable set of tags: type + Add to append, tap a tag's ✕ to remove.
/// Tags are lowercased and de-duplicated, matching the web app.
struct TagEditor: View {
    @Binding var tags: [String]
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 5) {
                            Text(tag)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                            Button {
                                tags.removeAll { $0 == tag }
                                Haptics.impact(.light)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.surface2, in: Capsule())
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Add tag", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(add)
                Button("Add", action: add)
                    .foregroundStyle(trimmed.isEmpty ? Theme.textTertiary : Theme.accent)
                    .disabled(trimmed.isEmpty)
            }
        }
    }

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func add() {
        let tag = trimmed.lowercased()
        draft = ""
        guard !tag.isEmpty, !tags.contains(tag) else { return }
        tags.append(tag)
        Haptics.selection()
    }
}

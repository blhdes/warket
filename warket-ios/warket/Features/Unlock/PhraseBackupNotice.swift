import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Shown under a freshly generated phrase. The 12 words are the only key and
/// cannot be reset, so the owner saves them and says so before the vault opens.
struct PhraseBackupNotice: View {
    let phrase: String
    @Binding var saved: Bool
    @Environment(ToastCenter.self) private var toast

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Write these 12 words down. They are the only key to this vault. There is no reset.")
            } icon: {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(.tint)
            }
            .font(.footnote.weight(.medium))

            Button(action: copy) {
                Label("Copy words", systemImage: "doc.on.doc")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)

            Toggle("I saved my 12 words", isOn: $saved)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .glassSurface(in: RoundedRectangle(cornerRadius: 16), tint: .accentColor)
    }

    /// The copy stays on this iPhone (no Universal Clipboard to your other devices)
    /// and clears itself after two minutes, so the words don't linger on the clipboard.
    private func copy() {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: phrase]],
            options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(120)]
        )
        Haptics.success()
        toast.show("Words copied. The copy clears in 2 minutes.", .success)
    }
}

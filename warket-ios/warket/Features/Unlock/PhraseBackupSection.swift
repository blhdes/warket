import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Shown under a freshly generated phrase. The 12 words are the only key and
/// cannot be reset, so the owner saves them and says so before the vault opens.
struct PhraseBackupSection: View {
    let phrase: String
    @Binding var saved: Bool
    @State private var copied = false

    var body: some View {
        Section {
            Label {
                Text("Write these 12 words down. They are the only key to this vault. There is no reset.")
            } icon: {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(.orange)
            }
            Button(copied ? "Copied" : "Copy Words",
                   systemImage: copied ? "checkmark" : "doc.on.doc",
                   action: copy)
                .contentTransition(.symbolEffect(.replace))
            Toggle("I saved my 12 words", isOn: $saved)
        } footer: {
            Text("The copy stays on this iPhone and clears itself after 2 minutes.")
        }
    }

    /// The copy stays on this iPhone (no Universal Clipboard to your other devices)
    /// and clears itself after two minutes, so the words don't linger on the clipboard.
    private func copy() {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: phrase]],
            options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(120)]
        )
        Haptics.success()
        copied = true
        Task {
            // `try?` only skips the cancellation of a 2-second wait, not a real error.
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}

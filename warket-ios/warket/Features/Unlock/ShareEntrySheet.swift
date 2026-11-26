import SwiftUI

/// Paste a share key to open someone's vault read-only. The server checks the key first.
struct ShareEntrySheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var shareKey = ""
    @State private var resolvingShare = false
    @State private var shareError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Paste 64-character key", text: $shareKey, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .fontDesign(.monospaced)
                        .lineLimit(2...4)
                } footer: {
                    if let shareError {
                        Text(shareError).foregroundStyle(.red)
                    } else {
                        Text("Paste a share key someone gave you. You'll see their vault but can't make changes.")
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Open Shared Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if resolvingShare {
                        ProgressView()
                    } else {
                        Button("Open", role: .confirm) { Task { await resolveShare() } }
                            .disabled(!canOpenShare)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var canOpenShare: Bool {
        !shareKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func resolveShare() async {
        let key = shareKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return }
        shareError = nil
        guard VaultAccess.isValidKey(key) else {
            shareError = "Invalid or expired share key."
            Haptics.error()
            return
        }
        resolvingShare = true
        defer { resolvingShare = false }
        do {
            // The server answers an unknown key with "Invalid or expired share key."
            try await VaultRepository(access: .shared(shareKey: key)).checkAccess()
            Haptics.success()
            dismiss()
            session.openShared(shareKey: key)
        } catch {
            shareError = error.userMessage
            Haptics.error()
        }
    }
}

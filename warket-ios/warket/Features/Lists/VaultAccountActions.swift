import SwiftUI

/// The account part of the lists menu, kept out of `ListsView`.
enum AccountPrompt: Equatable {
    case about, lock, deleteVault
}

/// About (a sheet), Lock (asks first) and Delete vault (a sheet that asks, then a
/// final dialog). Setting the bound `prompt` opens the matching one.
private struct VaultAccountActions: ViewModifier {
    @Binding var prompt: AccountPrompt?
    let repo: VaultRepository
    @Environment(Session.self) private var session

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: shows(.about)) { AboutView() }
            .sheet(isPresented: shows(.deleteVault)) {
                DeleteVaultSheet(repo: repo)
                    .presentationDetents([.medium, .large])
            }
            .confirmationDialog("Lock this vault?", isPresented: shows(.lock), titleVisibility: .visible) {
                Button("Lock vault", role: .destructive) { session.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will need your 12 words to get back in.")
            }
    }

    private func shows(_ value: AccountPrompt) -> Binding<Bool> {
        Binding(
            get: { prompt == value },
            set: { if !$0, prompt == value { prompt = nil } }
        )
    }
}

extension View {
    func vaultAccountActions(_ prompt: Binding<AccountPrompt?>, repo: VaultRepository) -> some View {
        modifier(VaultAccountActions(prompt: prompt, repo: repo))
    }
}

/// First confirmation: what will be lost and a hint to export. The red button
/// then asks a second time before anything is sent to the server.
private struct DeleteVaultSheet: View {
    let repo: VaultRepository
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss

    @State private var confirming = false
    @State private var deleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        Text("Delete everything in this vault?").font(.headline)
                    } icon: {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }
                    Text("""
                    Every list and asset in this vault is erased from the server, and any share key \
                    you gave out stops working. Your 12 words will still open the vault, but it will be empty.
                    """)
                    .foregroundStyle(.secondary)
                } footer: {
                    Text("Want a copy first? Close this and use Export Vault.")
                }
                Section {
                    Button(role: .destructive) { confirming = true } label: {
                        if deleting { ProgressView() } else { Text("Delete Vault") }
                    }
                    .disabled(deleting)
                } footer: {
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Delete Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }.disabled(deleting)
                }
            }
        }
        .interactiveDismissDisabled(deleting)
        .confirmationDialog("Delete this vault forever?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Delete forever", role: .destructive) { Task { await deleteVault() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func deleteVault() async {
        deleting = true
        errorMessage = nil
        defer { deleting = false }
        do {
            try await repo.deleteVault()
            Haptics.success()
            toast.show("Vault deleted", .success)
            dismiss()
            session.signOut()
        } catch {
            // Shown in the sheet: a toast would sit hidden behind it.
            Haptics.error()
            errorMessage = error.userMessage
        }
    }
}

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The transfer part of the lists menu, kept out of `ListsView`.
enum TransferRequest: Equatable {
    case export, importFile, share
}

/// Export (a JSON file), Import (merges a JSON file into the vault) and Share (a read-only key
/// copied to the clipboard). Setting the bound `request` starts the matching one.
private struct VaultTransferActions: ViewModifier {
    @Binding var request: TransferRequest?
    let repo: VaultRepository
    let onImported: () async -> Void
    @Environment(ToastCenter.self) private var toast

    @State private var exportDoc: JSONDocument?
    @State private var showExporter = false
    @State private var showImporter = false

    func body(content: Content) -> some View {
        content
            .fileExporter(
                isPresented: $showExporter,
                document: exportDoc,
                contentType: .json,
                defaultFilename: exportFilename
            ) { result in
                if case .failure(let error) = result {
                    toast.show(error.userMessage, .error)
                } else {
                    Haptics.success()
                    toast.show("Vault exported", .success)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json]
            ) { result in
                Task { await handleImport(result) }
            }
            .onChange(of: request) { _, new in
                guard let new else { return }
                request = nil
                switch new {
                case .export: Task { await prepareExport() }
                case .importFile: showImporter = true
                case .share: Task { await shareVault() }
                }
            }
    }

    private var exportFilename: String {
        let formatter = DateFormatter()
        // Fixed locale and calendar, so a phone set to e.g. the Buddhist calendar still gets 2026, not 2569.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return "warket-export-\(formatter.string(from: Date()))"
    }

    private func prepareExport() async {
        do {
            let export = try await repo.exportVault()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            exportDoc = JSONDocument(data: try encoder.encode(export))
            showExporter = true
        } catch {
            Haptics.error()
            toast.show(error.userMessage, .error)
        }
    }

    private func handleImport(_ result: Result<URL, Error>) async {
        let url: URL
        switch result {
        case .success(let picked): url = picked
        case .failure(let error):
            toast.show(error.userMessage, .error)
            return
        }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(VaultExport.self, from: data)
            if let message = VaultExport.validate(decoded) {
                toast.show(message, .error)
                return
            }
            let summary = try await repo.importVault(decoded)
            Haptics.success()
            toast.show("Imported \(summary.lists) lists, \(summary.assets) assets", .success)
            await onImported()
        } catch is DecodingError {
            Haptics.error()
            toast.show("Invalid or unrecognized file", .error)
        } catch {
            Haptics.error()
            toast.show(error.userMessage, .error)
        }
    }

    /// Create/refresh a read-only share key and copy it to the clipboard, so it
    /// can be pasted into another device's "Open a shared vault" field.
    private func shareVault() async {
        do {
            let key = try await repo.upsertShare()
            UIPasteboard.general.string = key
            Haptics.success()
            toast.show("Share key copied to clipboard", .success)
        } catch {
            Haptics.error()
            toast.show(error.userMessage, .error)
        }
    }
}

extension View {
    func vaultTransferActions(
        _ request: Binding<TransferRequest?>,
        repo: VaultRepository,
        onImported: @escaping () async -> Void
    ) -> some View {
        modifier(VaultTransferActions(request: request, repo: repo, onImported: onImported))
    }
}

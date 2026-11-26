import SwiftUI

extension Resource {
    /// Build a Resource from a raw URL, deriving the favicon from the host
    /// (matching the web app's Google s2 favicon URL). Adds https:// if missing.
    static func make(title: String, url rawURL: String) -> Resource {
        var url = rawURL.trimmingCharacters(in: .whitespaces)
        if !url.isEmpty, !url.contains("://") { url = "https://" + url }
        let host = URL(string: url)?.host() ?? ""
        let favicon = host.isEmpty ? "" : "https://www.google.com/s2/favicons?domain=\(host)&sz=32"
        return Resource(title: title.trimmingCharacters(in: .whitespaces), url: url, favicon: favicon)
    }
}

/// Add a single resource link (URL + optional title). Favicon is derived on add.
struct AddResourceSheet: View {
    let onAdd: (Resource) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var title = ""
    @State private var fetching = false
    @State private var fetchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .submitLabel(.done)
                        .onSubmit { autofillTitle() }
                    HStack {
                        TextField("Title (optional)", text: $title)
                        if fetching {
                            ProgressView()
                        } else if !url.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button("Fetch Title", systemImage: "arrow.down.circle") { autofillTitle(force: true) }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                        }
                    }
                } footer: {
                    Text("Paste a link, then tap the arrow to pull in its title.")
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Resource")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", role: .confirm) {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
                        onAdd(Resource.make(title: trimmedTitle.isEmpty ? url : trimmedTitle, url: url))
                        Haptics.selection()
                        dismiss()
                    }
                    .disabled(!isValidLink)
                }
            }
            .presentationDetents([.medium])
        }
    }

    /// True when the text, after `Resource.make` adds https:// if needed, is a web
    /// address with a real host name (so "hello" or "tel:123" can't be saved as links).
    private var isValidLink: Bool {
        let candidate = Resource.make(title: "", url: url).url
        guard !candidate.contains(where: \.isWhitespace),
              let parsed = URL(string: candidate), parsed.isWebLink,
              let host = parsed.host(), host.contains(".")
        else { return false }
        return true
    }

    /// Fetch the page title for the entered URL. Auto-fill only overwrites an
    /// empty title; the manual button (`force`) always replaces it. Single-flight:
    /// a new request cancels the previous so an overlapping fetch can't clobber
    /// the result or leave the spinner stuck.
    private func autofillTitle(force: Bool = false) {
        let trimmedURL = url.trimmingCharacters(in: .whitespaces)
        guard !trimmedURL.isEmpty else { return }
        if !force, !title.trimmingCharacters(in: .whitespaces).isEmpty { return }

        fetchTask?.cancel()
        fetchTask = Task { @MainActor in
            fetching = true
            let fetched = await TitleFetcher.fetch(trimmedURL)
            if Task.isCancelled { return }
            fetching = false

            guard let fetched, !fetched.isEmpty else { return }
            if force || title.trimmingCharacters(in: .whitespaces).isEmpty {
                title = fetched
                Haptics.selection()
            }
        }
    }
}

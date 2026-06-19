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
                Section("Link") {
                    TextField("URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .submitLabel(.done)
                        .onSubmit { autofillTitle() }
                    HStack {
                        TextField("Title (optional)", text: $title)
                        if fetching {
                            ProgressView().controlSize(.small)
                        } else if !url.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button {
                                autofillTitle(force: true)
                            } label: {
                                Image(systemName: "arrow.down.circle")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.accent)
                            .accessibilityLabel("Fetch title from link")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.surface0)
            .navigationTitle("Add Resource")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
                        onAdd(Resource.make(title: trimmedTitle.isEmpty ? url : trimmedTitle, url: url))
                        Haptics.selection()
                        dismiss()
                    }
                    .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .presentationDetents([.medium])
        }
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

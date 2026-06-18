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

    var body: some View {
        NavigationStack {
            Form {
                Section("Link") {
                    TextField("URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Title (optional)", text: $title)
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
}

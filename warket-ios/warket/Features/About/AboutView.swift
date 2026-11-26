import SwiftUI

/// App name and version, how the vault works in plain words, and the privacy
/// policy and support links Apple asks for. Opened from the lists menu and from
/// the unlock screen.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 6) {
                        WarketMark(size: 56)
                        Text("warket")
                            .font(.serif(48, relativeTo: .largeTitle))
                        Text(versionText)
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                Section("How Your Vault Works") {
                    Text("""
                    Your 12 words are the key to your vault. They never leave this iPhone: the app turns \
                    them into a long code and uses only that code to reach your vault. Your lists and \
                    assets are stored on the warket server under a fingerprint of that code, with no \
                    account, name or email.
                    """)
                    Text("""
                    Anyone with your 12 words can open your vault, and there is no way to reset them. \
                    Keep them somewhere safe. A share key only lets someone look, never change anything.
                    """)
                }
                Section {
                    linkRow("Privacy Policy", icon: "hand.raised", url: AppLinks.privacyPolicy)
                    linkRow("Support", icon: "questionmark.circle", url: AppLinks.support)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }

    private func linkRow(_ title: String, icon: String, url: URL) -> some View {
        Button { openURL(url, prefersInApp: true) } label: {
            Label(title, systemImage: icon)
        }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }
}

#Preview {
    AboutView()
}

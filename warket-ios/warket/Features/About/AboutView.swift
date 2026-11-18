import SwiftUI

/// App name and version, how the vault works in plain words, and the privacy
/// policy and support links Apple asks for. Opened from the lists menu and from
/// the unlock screen.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MarketPulseBackground()
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        howItWorks
                        links
                    }
                    .padding(24)
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            WarketMark(size: 56)
                .padding(.bottom, 2)
            Text("warket")
                .font(.serif(48, relativeTo: .largeTitle))
                .foregroundStyle(Theme.textPrimary)
            Text(versionText)
                .font(.mono(13, relativeTo: .footnote))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.top, 8)
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How your vault works")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
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
        .font(.subheadline)
        .foregroundStyle(Theme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassSurface(in: RoundedRectangle(cornerRadius: 16))
    }

    private var links: some View {
        VStack(spacing: 10) {
            linkRow("Privacy Policy", icon: "hand.raised", url: AppLinks.privacyPolicy)
            linkRow("Support", icon: "questionmark.circle", url: AppLinks.support)
        }
    }

    private func linkRow(_ title: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(Theme.textTertiary)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassSurface(in: RoundedRectangle(cornerRadius: 16))
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

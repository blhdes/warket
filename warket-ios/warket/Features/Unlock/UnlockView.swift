import SwiftUI

/// Vault unlock: enter (or generate) a 12-word phrase, hash it locally, and open
/// the vault. The phrase never leaves the device — only the resulting hash is
/// handed to the Session.
struct UnlockView: View {
    @Environment(Session.self) private var session

    @State private var phrase = ""
    @State private var remember = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.surface0.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    phraseField

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.error)
                    }

                    Button(action: generate) {
                        Label("Generate new phrase", systemImage: "wand.and.stars")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)

                    Toggle("Keep me signed in", isOn: $remember)
                        .tint(Theme.accent)
                        .foregroundStyle(Theme.textSecondary)
                        .font(.subheadline)

                    accessButton
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("warket")
                .font(.serif(52, relativeTo: .largeTitle))
                .foregroundStyle(Theme.textPrimary)
            Text("Enter your 12-word phrase to open your vault.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 40)
        .padding(.bottom, 8)
    }

    private var phraseField: some View {
        TextField("twelve words separated by spaces", text: $phrase, axis: .vertical)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .font(.mono(17, relativeTo: .body))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(3...6)
            .padding(14)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.borderDefault, lineWidth: 1)
            )
    }

    private var accessButton: some View {
        Button(action: access) {
            Text("Access vault")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    canAccess ? Theme.accent : Theme.surface3,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.lg)
                )
                .foregroundStyle(canAccess ? .white : Theme.textTertiary)
        }
        .disabled(!canAccess)
        .padding(.top, 4)
    }

    private var canAccess: Bool {
        !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func generate() {
        phrase = SeedPhrase.generate()
        errorMessage = nil
    }

    private func access() {
        do {
            let hash = try SeedPhrase.hash(phrase)
            session.unlock(hash: hash, remember: remember)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    UnlockView()
        .environment(Session())
        .preferredColorScheme(.dark)
}

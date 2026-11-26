import SwiftUI

/// Vault unlock: enter (or generate) a 12-word phrase, hash it locally, and open
/// the vault. The phrase never leaves the device — only the resulting hash is
/// handed to the Session.
struct UnlockView: View {
    @Environment(Session.self) private var session

    @State private var phrase = ""
    @State private var remember = true
    @State private var errorMessage: String?
    /// The last generated phrase (normalized) and whether its owner said it is saved.
    @State private var generatedPhrase: String?
    @State private var phraseSaved = false
    @State private var showingAbout = false

    @State private var generateTick = 0

    @State private var showingShareEntry = false

    var body: some View {
        Form {
            Section {
                TextField("Twelve words separated by spaces", text: $phrase, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .fontDesign(.monospaced)
                    .lineLimit(3...6)
                Button("Generate New Phrase", systemImage: "wand.and.stars", action: generate)
                    .symbolEffect(.bounce, value: generateTick)
            } header: {
                header
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            if needsBackup {
                PhraseBackupSection(phrase: phrase, saved: $phraseSaved)
            }

            Section {
                Toggle("Keep Me Signed In", isOn: $remember)
            }

            Section {
                Button("Open a Shared Vault", systemImage: "eye") { showingShareEntry = true }
                Button("About & Privacy", systemImage: "info.circle") { showingAbout = true }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaBar(edge: .bottom) {
            Button("Access Vault", action: access)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .buttonSizing(.flexible)
                .disabled(!canAccess)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .animation(.default, value: needsBackup)
        .sheet(isPresented: $showingShareEntry) { ShareEntrySheet() }
        .sheet(isPresented: $showingAbout) { AboutView() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            WarketMark(size: 64)
            Text("warket")
                .font(.serif(52, relativeTo: .largeTitle))
                .foregroundStyle(.primary)
            Text("Your private asset vault.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .textCase(nil)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private var canAccess: Bool {
        !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (!needsBackup || phraseSaved)
    }

    /// A generated phrase must be confirmed as saved. Once the words are edited it
    /// counts as a typed phrase (spaces and capitals do not count as edits).
    private var needsBackup: Bool {
        generatedPhrase != nil && SeedPhrase.normalize(phrase) == generatedPhrase
    }

    private func generate() {
        phrase = SeedPhrase.generate()
        generatedPhrase = phrase
        phraseSaved = false
        errorMessage = nil
        generateTick += 1
    }

    private func access() {
        guard canAccess else { return }
        do {
            let hash = try SeedPhrase.hash(phrase)
            session.unlock(hash: hash, remember: remember)
        } catch let error as SeedPhraseError {
            errorMessage = error.localizedDescription // the word-count message, already plain
        } catch {
            errorMessage = error.userMessage
        }
    }
}

#Preview {
    UnlockView()
        .environment(Session())
}

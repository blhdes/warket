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
    @State private var shareKey = ""
    @State private var resolvingShare = false
    @State private var shareError: String?

    var body: some View {
        ZStack {
            MarketPulseBackground()

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 48)
                        cluster
                        Spacer(minLength: 24)
                        aboutButton
                    }
                    .frame(minHeight: proxy.size.height, alignment: .center)
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .sheet(isPresented: $showingShareEntry) { shareEntrySheet }
        .sheet(isPresented: $showingAbout) { AboutView() }
    }

    private var cluster: some View {
        VStack(spacing: 26) {
            header

            VStack(spacing: 14) {
                phraseField
                generateButton
                if needsBackup {
                    PhraseBackupNotice(phrase: phrase, saved: $phraseSaved)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            toggleRow
            accessButton
            sharedVaultButton
        }
        .animation(.snappy(duration: 0.3), value: needsBackup)
    }

    private var aboutButton: some View {
        Button { showingAbout = true } label: {
            Text("About & Privacy")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }

    private var sharedVaultButton: some View {
        Button { showingShareEntry = true } label: {
            Label("Open a shared vault", systemImage: "eye")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var shareEntrySheet: some View {
        NavigationStack {
            ZStack {
                MarketPulseBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 10) {
                            Image(systemName: "eye")
                                .font(.largeTitle)
                                .foregroundStyle(.tint)
                            Text("Open a read-only vault")
                                .font(.headline)
                            Text("Paste a share key someone gave you. You'll see their vault but can't make changes.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        TextField("Paste 64-character key", text: $shareKey, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .fontDesign(.monospaced)
                            .lineLimit(2...4)
                            .padding(16)
                            .glassSurface(in: RoundedRectangle(cornerRadius: 16))

                        if let shareError {
                            Label(shareError, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        openShareButton
                    }
                    .padding(24)
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Shared vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingShareEntry = false }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var openShareButton: some View {
        Button { Task { await resolveShare() } } label: {
            Group {
                if resolvingShare {
                    ProgressView()
                } else {
                    Text("Open Vault")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .disabled(!canOpenShare || resolvingShare)
    }

    private var canOpenShare: Bool {
        !shareKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var header: some View {
        VStack(spacing: 10) {
            WarketMark(size: 64)
                .padding(.bottom, 2)
            Text("warket")
                .font(.serif(64, relativeTo: .largeTitle))
            Text("Your private asset vault.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.bottom, 4)
    }

    private var phraseField: some View {
        TextField("twelve words separated by spaces", text: $phrase, axis: .vertical)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .fontDesign(.monospaced)
            .lineLimit(3...6)
            .padding(16)
            .glassSurface(in: RoundedRectangle(cornerRadius: 16))
    }

    private var generateButton: some View {
        Button(action: generate) {
            Label("Generate new phrase", systemImage: "wand.and.stars")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: generateTick)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .glassSurface(in: Capsule(), tint: .accentColor)
        }
        .buttonStyle(.plain)
    }

    private var toggleRow: some View {
        Toggle("Keep me signed in", isOn: $remember)
            .foregroundStyle(.secondary)
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassSurface(in: RoundedRectangle(cornerRadius: 16))
    }

    private var accessButton: some View {
        Button(action: access) {
            Text("Access Vault")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .disabled(!canAccess)
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
            showingShareEntry = false
            session.openShared(shareKey: key)
        } catch {
            shareError = error.userMessage
            Haptics.error()
        }
    }
}

#Preview {
    UnlockView()
        .environment(Session())
        .environment(ToastCenter())
}

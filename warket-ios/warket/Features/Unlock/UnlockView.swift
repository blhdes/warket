import SwiftUI

/// Vault unlock: enter (or generate) a 12-word phrase, hash it locally, and open
/// the vault. The phrase never leaves the device — only the resulting hash is
/// handed to the Session.
struct UnlockView: View {
    @Environment(Session.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phrase = ""
    @State private var remember = true
    @State private var errorMessage: String?

    @State private var appeared = false
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
                    }
                    .frame(minHeight: proxy.size.height, alignment: .center)
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.smooth(duration: 0.6).delay(0.05)) { appeared = true }
            }
        }
        .sheet(isPresented: $showingShareEntry) { shareEntrySheet }
    }

    private var cluster: some View {
        VStack(spacing: 26) {
            header

            VStack(spacing: 14) {
                phraseField
                generateButton
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            toggleRow
            accessButton
            sharedVaultButton
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private var sharedVaultButton: some View {
        Button { showingShareEntry = true } label: {
            Label("Open a shared vault", systemImage: "eye")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
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
                                .foregroundStyle(Theme.accent)
                            Text("Open a read-only vault")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Paste a share key someone gave you. You'll see their vault but can't make changes.")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        TextField("Paste 64-character key", text: $shareKey, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.mono(15, relativeTo: .body))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2...4)
                            .padding(16)
                            .glassSurface(in: RoundedRectangle(cornerRadius: 16))

                        if let shareError {
                            Label(shareError, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(Theme.error)
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
                    ProgressView().tint(.white)
                } else {
                    Text("Open vault").font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(canOpenShare ? .white : Theme.textTertiary)
            .background {
                Capsule().fill(
                    canOpenShare
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Theme.accent, Theme.accentHover],
                            startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Theme.surface3)
                )
            }
            .shadow(color: Theme.accent.opacity(canOpenShare ? 0.30 : 0), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!canOpenShare || resolvingShare)
        .animation(.snappy(duration: 0.25), value: canOpenShare)
    }

    private var canOpenShare: Bool {
        !shareKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("warket")
                .font(.serif(64, relativeTo: .largeTitle))
                .foregroundStyle(Theme.textPrimary)
            Text("Your private asset vault.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.bottom, 4)
    }

    private var phraseField: some View {
        TextField("twelve words separated by spaces", text: $phrase, axis: .vertical)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .font(.mono(17, relativeTo: .body))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(3...6)
            .padding(16)
            .glassSurface(in: RoundedRectangle(cornerRadius: 16))
    }

    private var generateButton: some View {
        Button(action: generate) {
            Label("Generate new phrase", systemImage: "wand.and.stars")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.bounce, value: generateTick)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .glassSurface(in: Capsule(), tint: Theme.accent)
        }
        .buttonStyle(.plain)
    }

    private var toggleRow: some View {
        Toggle("Keep me signed in", isOn: $remember)
            .tint(Theme.accent)
            .foregroundStyle(Theme.textSecondary)
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassSurface(in: RoundedRectangle(cornerRadius: 16))
    }

    private var accessButton: some View {
        Button(action: access) {
            Text("Access vault")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(canAccess ? .white : Theme.textTertiary)
                .background {
                    Capsule().fill(
                        canAccess
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Theme.accent, Theme.accentHover],
                                startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Theme.surface3)
                    )
                }
                .shadow(color: Theme.accent.opacity(canAccess ? 0.30 : 0), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!canAccess)
        .animation(.snappy(duration: 0.25), value: canAccess)
    }

    private var canAccess: Bool {
        !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func generate() {
        phrase = SeedPhrase.generate()
        errorMessage = nil
        generateTick += 1
    }

    private func access() {
        do {
            let hash = try SeedPhrase.hash(phrase)
            session.unlock(hash: hash, remember: remember)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveShare() async {
        let key = shareKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return }
        shareError = nil
        resolvingShare = true
        defer { resolvingShare = false }
        do {
            guard let vaultHash = try await ShareResolver.resolve(shareHash: key) else {
                shareError = "Invalid or expired share key."
                Haptics.error()
                return
            }
            Haptics.success()
            showingShareEntry = false
            session.openShared(hash: vaultHash)
        } catch {
            shareError = error.localizedDescription
            Haptics.error()
        }
    }
}

#Preview {
    UnlockView()
        .environment(Session())
}

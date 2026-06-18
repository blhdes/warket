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
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
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
}

#Preview {
    UnlockView()
        .environment(Session())
        .preferredColorScheme(.dark)
}

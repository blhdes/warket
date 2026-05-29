import Foundation
import CryptoKit

enum SeedPhraseError: LocalizedError, Equatable {
    case invalidWordCount(Int)

    var errorDescription: String? {
        switch self {
        case .invalidWordCount(let count):
            return "Seed phrase must be exactly 12 words, got \(count)"
        }
    }
}

/// Local-only seed-phrase operations. Ported byte-for-byte from the web app's
/// `src/features/auth/seedPhrase.ts` so existing vaults open unchanged.
///
/// ⚠️ A phrase must NEVER leave the device. Only the resulting hash is sent to
/// Supabase (via the `x-vault-hash` header).
enum SeedPhrase {

    /// Generate a random 12-word phrase from the curated `Wordlist`.
    static func generate() -> String {
        (0..<12).map { _ in Wordlist.words.randomElement()! }.joined(separator: " ")
    }

    /// Normalize like the JS version: lowercase -> trim -> collapse whitespace runs.
    static func normalize(_ phrase: String) -> String {
        let lowered = phrase.lowercased()
        let trimmed = lowered.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
    }

    /// SHA-256 of the normalized phrase, as lowercase hex. Throws if not 12 words.
    static func hash(_ phrase: String) throws -> String {
        let normalized = normalize(phrase)
        let wordCount = normalized.isEmpty ? 0 : normalized.split(separator: " ").count
        guard wordCount == 12 else {
            throw SeedPhraseError.invalidWordCount(wordCount)
        }
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.hexString
    }

    /// Derive a deterministic, one-way share hash from a vault hash.
    /// Domain-separated with ":share" so it can't be reversed to the vault hash.
    static func deriveShareHash(_ vaultHash: String) -> String {
        let digest = SHA256.hash(data: Data((vaultHash + ":share").utf8))
        return digest.hexString
    }
}

private extension SHA256Digest {
    /// Lowercase hex string, matching JS `b.toString(16).padStart(2, '0')`.
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

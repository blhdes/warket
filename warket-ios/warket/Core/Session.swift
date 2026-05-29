import Foundation
import Observation

/// Holds the unlocked vault hash for the app's lifetime and, optionally, across
/// launches ("keep me signed in"). Only the hash is persisted — never the seed
/// phrase. The hash is the identity token, so storing it in UserDefaults is fine.
@Observable
final class Session {
    private let defaults = UserDefaults.standard
    private let hashKey = "warket.vault_hash"
    private let rememberKey = "warket.remember"

    private(set) var vaultHash: String?

    init() {
        if defaults.bool(forKey: rememberKey),
           let saved = defaults.string(forKey: hashKey), !saved.isEmpty {
            vaultHash = saved
        }
    }

    func unlock(hash: String, remember: Bool) {
        vaultHash = hash
        defaults.set(remember, forKey: rememberKey)
        if remember {
            defaults.set(hash, forKey: hashKey)
        } else {
            defaults.removeObject(forKey: hashKey)
        }
    }

    func signOut() {
        vaultHash = nil
        defaults.removeObject(forKey: hashKey)
        defaults.set(false, forKey: rememberKey)
    }
}

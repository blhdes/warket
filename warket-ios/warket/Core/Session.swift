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
    /// True when the open vault came from a share key — the UI hides all writes.
    private(set) var readOnly = false

    init() {
        if defaults.bool(forKey: rememberKey),
           let saved = defaults.string(forKey: hashKey), !saved.isEmpty {
            vaultHash = saved
        }
    }

    func unlock(hash: String, remember: Bool) {
        readOnly = false
        vaultHash = hash
        defaults.set(remember, forKey: rememberKey)
        if remember {
            defaults.set(hash, forKey: hashKey)
        } else {
            defaults.removeObject(forKey: hashKey)
        }
    }

    /// Open a vault read-only from an already-resolved share. Never persisted, so
    /// a shared view is gone on next launch.
    func openShared(hash: String) {
        readOnly = true
        vaultHash = hash
        defaults.removeObject(forKey: hashKey)
        defaults.set(false, forKey: rememberKey)
    }

    func signOut() {
        readOnly = false
        vaultHash = nil
        defaults.removeObject(forKey: hashKey)
        defaults.set(false, forKey: rememberKey)
    }
}

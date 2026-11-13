import Foundation
import Observation

/// Holds the open vault for the app's lifetime and, optionally, across launches
/// ("keep me signed in"). Only the owner's vault hash is persisted, never the seed
/// phrase and never a share key.
@Observable
final class Session {
    private let defaults = UserDefaults.standard
    private let hashKey = "warket.vault_hash"
    private let rememberKey = "warket.remember"

    /// The open vault, or nil while the unlock screen shows. A shared vault is read-only.
    private(set) var access: VaultAccess?

    init() {
        if defaults.bool(forKey: rememberKey),
           let saved = defaults.string(forKey: hashKey), !saved.isEmpty {
            access = .owner(vaultHash: saved)
        }
    }

    func unlock(hash: String, remember: Bool) {
        access = .owner(vaultHash: hash)
        defaults.set(remember, forKey: rememberKey)
        if remember {
            defaults.set(hash, forKey: hashKey)
        } else {
            defaults.removeObject(forKey: hashKey)
        }
    }

    /// Open a vault read-only with a share key the server already accepted. Never
    /// persisted, so a shared view is gone on next launch.
    func openShared(shareKey: String) {
        access = .shared(shareKey: shareKey)
        defaults.removeObject(forKey: hashKey)
        defaults.set(false, forKey: rememberKey)
    }

    func signOut() {
        access = nil
        defaults.removeObject(forKey: hashKey)
        defaults.set(false, forKey: rememberKey)
    }
}

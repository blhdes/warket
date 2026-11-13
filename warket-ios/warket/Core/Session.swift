import Foundation
import Observation

/// Holds the open vault for the app's lifetime and, optionally, across launches
/// ("keep me signed in"). Only the owner's vault hash is kept, in the Keychain,
/// never the seed phrase and never a share key.
@Observable
final class Session {
    private let defaults = UserDefaults.standard
    private let keychain = KeychainStore()
    private let hashAccount = "vault_hash"
    private let rememberKey = "warket.remember"
    /// Builds before 1.0 kept the hash here, in a plain file that goes into backups.
    private let legacyHashKey = "warket.vault_hash"

    /// The open vault, or nil while the unlock screen shows. A shared vault is read-only.
    private(set) var access: VaultAccess?

    init() {
        guard defaults.bool(forKey: rememberKey) else {
            // UserDefaults is wiped when the app is deleted, the Keychain is not.
            // So "not remembered" also covers a reinstall: drop any leftover key.
            defaults.removeObject(forKey: legacyHashKey)
            keychain.remove(hashAccount)
            return
        }

        let legacy = defaults.string(forKey: legacyHashKey)
        if let legacy, keychain.set(legacy, for: hashAccount) {
            defaults.removeObject(forKey: legacyHashKey)
        }
        // If the move failed, the old copy is still used and the move is tried again next launch.
        guard let saved = keychain.get(hashAccount) ?? legacy, VaultAccess.isValidKey(saved) else { return }
        access = .owner(vaultHash: saved)
    }

    func unlock(hash: String, remember: Bool) {
        access = .owner(vaultHash: hash)
        defaults.set(remember, forKey: rememberKey)
        if remember {
            keychain.set(hash, for: hashAccount)
        } else {
            keychain.remove(hashAccount)
        }
    }

    /// Open a vault read-only with a share key the server already accepted. Never
    /// persisted, so a shared view is gone on next launch.
    func openShared(shareKey: String) {
        access = .shared(shareKey: shareKey)
        forget()
    }

    func signOut() {
        access = nil
        forget()
    }

    private func forget() {
        keychain.remove(hashAccount)
        defaults.set(false, forKey: rememberKey)
    }
}

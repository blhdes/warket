import Foundation
import os
import Security

extension Logger {
    static let keychain = Logger(subsystem: "com.blhdes.warket", category: "keychain")
}

/// Text secrets kept in the iOS Keychain between launches. Items stay on this
/// device only: no iCloud Keychain sync and no backups, so a new phone needs the
/// 12 words. Unlike UserDefaults, an item can outlive a deleted app (see `Session.init`).
struct KeychainStore {
    var service = "com.blhdes.warket"

    /// Saves or replaces the value. Returns false (and logs) when the Keychain refuses.
    @discardableResult
    func set(_ value: String, for account: String) -> Bool {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(query(account) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query(account).merging(attributes) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            Logger.keychain.error("Could not save \(account, privacy: .public): OSStatus \(status)")
            return false
        }
        return true
    }

    func get(_ account: String) -> String? {
        var request = query(account)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            Logger.keychain.error("Could not read \(account, privacy: .public): OSStatus \(status)")
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func remove(_ account: String) {
        let status = SecItemDelete(query(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            Logger.keychain.error("Could not remove \(account, privacy: .public): OSStatus \(status)")
            return
        }
    }

    private func query(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

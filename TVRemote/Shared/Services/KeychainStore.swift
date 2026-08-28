import Foundation
import Security

/// Stores the TV's `client-key` in the keychain.
///
/// The key is a bearer credential: anything holding it can control the
/// television without the pairing prompt appearing. That is not high-value,
/// but the keychain is the right home for it and costs nothing over
/// `UserDefaults`.
///
/// Two details matter more than they look, because getting either wrong makes
/// the TV re-prompt on every install and the app has no way to tell:
///
/// - **On iOS**, `keychain-access-groups` is declared in the entitlements so
///   the item lands in a group keyed by team and bundle id rather than
///   whatever the current signing default happens to be. The group itself is
///   deliberately not passed in the query: leaving it unset uses the first
///   entry in the entitlement, which avoids hard-coding the team prefix.
/// - **On macOS**, the item's access is tied to the *signing identity* of the
///   binary that created it. `kSecUseDataProtectionKeychain` would key on the
///   access group instead, but on macOS that requires the same
///   `keychain-access-groups` entitlement — which forces a provisioning
///   profile onto a Developer ID app for no other benefit. So macOS uses the
///   file keychain, and the rule is simply: **do not alternate between
///   Development-signed and Developer ID-signed builds of the same app**, or
///   each swap orphans the stored key and the TV prompts again.
enum KeychainStore {

    /// The keychain account for a TV, scoped to the manifest revision the key
    /// was issued under. See `Config.manifestRevision`.
    static func account(forHost host: String) -> String {
        "\(host)#manifest\(Config.manifestRevision)"
    }

    static func loadClientKey(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Stores the key, returning the OSStatus so a failure can be reported
    /// rather than silently causing a re-pair on the next launch.
    @discardableResult
    static func saveClientKey(_ key: String, account: String) -> OSStatus {
        SecItemDelete(baseQuery(account: account) as CFDictionary)

        var insert = baseQuery(account: account)
        insert[kSecValueData as String] = Data(key.utf8)
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(insert as CFDictionary, nil)
    }

    static func deleteClientKey(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    /// Removes keys issued under earlier manifest revisions.
    ///
    /// They can never be used again — the permissions they carry are stale —
    /// and leaving them behind is a small pile of dead credentials.
    static func purgeSupersededKeys(forHost host: String) {
        guard Config.manifestRevision > 1 else { return }
        for revision in 1..<Config.manifestRevision {
            let stale = revision == 1 ? host : "\(host)#manifest\(revision)"
            SecItemDelete(baseQuery(account: stale) as CFDictionary)
        }
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.keychainService,
            kSecAttrAccount as String: account,
        ]
    }
}

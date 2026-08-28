import Foundation
import Security

/// Stores the TV's `client-key` in the keychain.
///
/// The key is a bearer credential: anything holding it can control the
/// television without the pairing prompt appearing. That is not high-value,
/// but the keychain is the right home for it and costs nothing over
/// `UserDefaults`.
enum KeychainStore {

    /// The keychain account for a TV, scoped to the manifest revision the key
    /// was issued under. See `Config.manifestRevision`.
    static func account(forHost host: String) -> String {
        "\(host)#manifest\(Config.manifestRevision)"
    }

    static func loadClientKey(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func saveClientKey(_ key: String, account: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)

        var insert = base
        insert[kSecValueData as String] = Data(key.utf8)
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }

    static func deleteClientKey(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

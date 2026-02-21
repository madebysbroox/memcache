import Foundation
import Security

/// Simple Keychain wrapper for storing and retrieving data securely.
/// Used primarily for persisting OAuth tokens.
enum KeychainHelper {
    private static let serviceName = "com.memcache.app"

    /// Save data to the Keychain for a given key.
    /// Returns true if the save (or update) succeeded.
    @discardableResult
    static func save(key: String, data: Data) -> Bool {
        // Delete any existing item first to avoid duplicates
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Load data from the Keychain for a given key.
    /// Returns nil if the key does not exist or the read fails.
    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Delete a Keychain item for a given key.
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

import Foundation
import Security

/// Lightweight wrapper around the macOS Keychain for storing OAuth tokens.
enum KeychainHelper {

    /// Save or update a value in the Keychain.
    @discardableResult
    static func save(key: String, data: Data, service: String = Bundle.main.bundleIdentifier ?? "MenuBarMeetings") -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key
        ]

        // Delete any existing item first
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Read a value from the Keychain.
    static func read(key: String, service: String = Bundle.main.bundleIdentifier ?? "MenuBarMeetings") -> Data? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Delete a value from the Keychain.
    @discardableResult
    static func delete(key: String, service: String = Bundle.main.bundleIdentifier ?? "MenuBarMeetings") -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    // MARK: - Convenience for Codable types

    static func save<T: Encodable>(key: String, value: T) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return save(key: key, data: data)
    }

    static func read<T: Decodable>(key: String, as type: T.Type) -> T? {
        guard let data = read(key: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

import Foundation
import Security

/// Secrets dans le trousseau du Mac : token Todoist et clé API Claude.
enum Keychain {
    private static let service = "com.adnan.done"
    static let todoistAccount = "todoist-token"
    static let anthropicAccount = "anthropic-api-key"

    static func readToken() -> String? { read(todoistAccount) }

    @discardableResult
    static func saveToken(_ token: String) -> Bool { save(token, account: todoistAccount) }

    static func deleteToken() { delete(todoistAccount) }

    static func read(_ account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ value: String, account: String) -> Bool {
        delete(account)
        var query = baseQuery(account)
        query[kSecValueData as String] = Data(value.utf8)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func delete(_ account: String) {
        _ = SecItemDelete(baseQuery(account) as CFDictionary)
    }

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

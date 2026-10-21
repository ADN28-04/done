import Foundation
import Security

/// Stockage du token Todoist dans le trousseau du Mac.
enum Keychain {
    private static let service = "com.adnan.done"
    private static let account = "todoist-token"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func readToken() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func saveToken(_ token: String) -> Bool {
        deleteToken()
        var query = baseQuery
        query[kSecValueData as String] = Data(token.utf8)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func deleteToken() {
        _ = SecItemDelete(baseQuery as CFDictionary)
    }
}

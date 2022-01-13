import Foundation
import Security

public class KeychainManager {
    enum KeychainError: Error {
        case noPassword
        case unexpectedPasswordData
        case unhandledError(status: OSStatus)
    }
    private typealias KcM = KeychainManager
    private static let teamId = "8Y86453UA8"
    private static let sharedKeychainGroup = "\(KcM.teamId).group.chat.delta.ios"

    public static func getDBSecret() throws -> String {
        guard let secret = try? queryDBSecret() else {
            return try addDBSecret()
        }
        
        return secret
    }

    public static func deleteDBSecret() -> Bool {
        let query = [kSecClass as String: kSecClassGenericPassword,
                     kSecAttrAccount as String: "dc_db"
                    ] as CFDictionary

        let status = SecItemDelete(query)
        return status == errSecSuccess
    }

    private static func createRandomPassword() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZY1234567890"
        return String((0..<36).map { _ in letters.randomElement()! })
    }

    private static func addDBSecret() throws -> String {
        let keychainItemQuery = [
          kSecValueData: createRandomPassword().data(using: .utf8)!,
          kSecAttrAccount as String: "dc_db",
          kSecClass: kSecClassGenericPassword,
          kSecAttrAccessGroup as String: KeychainManager.sharedKeychainGroup as AnyObject
        ] as CFDictionary

        var ref: AnyObject?
        
        let status = SecItemAdd(keychainItemQuery, &ref)
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
        UserDefaults.shared?.set(true, forKey: UserDefaults.hasSavedKeyToKeychain)
        if let result = ref as? NSDictionary,
            let password = result[kSecValueData] as? String {
            return password
        }
        
        return try queryDBSecret()
    }

    private static func queryDBSecret() throws -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: "dc_db",
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecAttrAccessGroup as String: KeychainManager.sharedKeychainGroup as AnyObject,
                                    kSecReturnAttributes as String: true,
                                    kSecReturnData as String: true]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { throw KeychainError.noPassword }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
        
        guard let existingItem = item as? [String: Any],
            let passwordData = existingItem[kSecValueData as String] as? Data,
            let password = String(data: passwordData, encoding: String.Encoding.utf8)
        else {
            throw KeychainError.unexpectedPasswordData
        }

        return password
    }
}

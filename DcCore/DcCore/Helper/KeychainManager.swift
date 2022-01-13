import Foundation
import Security

public enum KeychainError: Error {
    case noPassword
    case unhandledError(message: String, status: OSStatus)
}

public class KeychainManager {
    private typealias KcM = KeychainManager
    private static let teamId = "8Y86453UA8"
    private static let sharedKeychainGroup = "\(KcM.teamId).group.chat.delta.ios"

    public static func getAccountSecret(accountID: Int) throws -> String {
        do {
            return try queryAccountSecret(id: accountID)
        } catch KeychainError.noPassword {
            return try addAccountSecret(id: accountID)
        }
    }

    /**
     * Deletes ALL secrets from keychain
     * @return true if secrets have been deleted successfully or no secrets found
     */
    public static func deleteDBSecrets() -> Bool {
        let query = [kSecClass as String: kSecClassGenericPassword,
                     kSecAttrAccessGroup as String: KcM.sharedKeychainGroup as AnyObject
                    ] as CFDictionary

        let status = SecItemDelete(query)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func createRandomPassword() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZY1234567890"
        return String((0..<36).map { _ in letters.randomElement()! })
    }

    private static func addAccountSecret(id: Int) throws -> String {
        let keychainItemQuery = [
          kSecValueData: createRandomPassword().data(using: .utf8)!,
          kSecAttrAccount as String: "\(id)",
          kSecClass: kSecClassGenericPassword,
          kSecAttrAccessGroup as String: KcM.sharedKeychainGroup as AnyObject,
        ] as CFDictionary

        let status = SecItemAdd(keychainItemQuery, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(message: "Error adding secret for account \(id)",
                                               status: status)
        }
        UserDefaults.shared?.set(true, forKey: UserDefaults.hasSavedKeyToKeychain)
        return try queryAccountSecret(id: id)
    }

    private static func queryAccountSecret(id: Int) throws -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: "\(id)",
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecAttrAccessGroup as String: KcM.sharedKeychainGroup as AnyObject,
                                    kSecReturnAttributes as String: true,
                                    kSecReturnData as String: true]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            throw KeychainError.noPassword
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(message: "Unknown error while querying secret for account \(id):",
                                               status: status)
        }
        
        guard let existingItem = item as? [String: Any],
            let passwordData = existingItem[kSecValueData as String] as? Data,
            let password = String(data: passwordData, encoding: String.Encoding.utf8)
        else {
            throw KeychainError.unhandledError(message: "Unexpected password data for accuont \(id)",
                                               status: 0)
        }
        return password
    }
}

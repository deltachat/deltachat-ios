import Foundation
public extension UserDefaults {
    static var hasExtensionAttemptedToSend = "hasExtensionAttemptedToSend"
    static var hasSavedKeyToKeychain = "hasSavedKeyToKeychain"
    static var shared: UserDefaults? {
        return UserDefaults(suiteName: "group.chat.delta.ios")
    }
}

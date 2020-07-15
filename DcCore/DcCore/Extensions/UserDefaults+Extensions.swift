import Foundation
public extension UserDefaults {
    static var hasExtensionAttemptedToSend = "hasExtensionAttemptedToSend"
    static var currAccountDbName = "currAccountDbName"
    static var prevAccountDbName = "prevAccountDbName"
    static var shared: UserDefaults? {
        return UserDefaults(suiteName: "group.chat.delta.ios")
    }
}

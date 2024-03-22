import Foundation
public extension UserDefaults {
    static var hasExtensionAttemptedToSend = "hasExtensionAttemptedToSend"
    static var hasSavedKeyToKeychain = "hasSavedKeyToKeychain"
    static var upgradedKeychainEntry = "upgradedKeychainEntry_"
    static var mainAppRunningKey = "mainAppRunning"
    static var nseFetchingKey = "nseFetching"

    static var shared: UserDefaults? {
        return UserDefaults(suiteName: "group.chat.delta.ios")
    }

    static var mainAppRunning: Bool {
        return shared?.bool(forKey: mainAppRunningKey) ?? false
    }

    static func setMainAppRunning(_ value: Bool = true) {
        shared?.setValue(value, forKey: mainAppRunningKey)
    }

    static var nseFetching: Bool {
        return shared?.bool(forKey: nseFetchingKey) ?? false
    }

    static func setNseFetching(_ value: Bool = true) {
        shared?.setValue(value, forKey: nseFetchingKey)
    }
}

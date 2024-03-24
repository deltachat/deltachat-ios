import Foundation
public extension UserDefaults {
    static var hasExtensionAttemptedToSend = "hasExtensionAttemptedToSend"
    static var hasSavedKeyToKeychain = "hasSavedKeyToKeychain"
    static var upgradedKeychainEntry = "upgradedKeychainEntry_"
    static var debugArrayKey = "notify-fetch-info"
    static var mainAppRunningKey = "mainAppRunning"
    static var nseFetchingKey = "nseFetching"

    static var shared: UserDefaults? {
        return UserDefaults(suiteName: "group.chat.delta.ios")
    }

    static var mainAppRunning: Bool {
        return shared?.bool(forKey: mainAppRunningKey) ?? false
    }

    static func setMainAppRunning(_ value: Bool = true) {
        UserDefaults.pushToDebugArray(value ? "➡️" : "🛑")
        shared?.setValue(value, forKey: mainAppRunningKey)
    }

    static var nseFetching: Bool {
        return shared?.bool(forKey: nseFetchingKey) ?? false
    }

    static func setNseFetching(_ value: Bool = true) {
        shared?.setValue(value, forKey: nseFetchingKey)
    }

    static func pushToDebugArray(_ value: String) {
        guard let shared else { return }
        let values = shared.array(forKey: debugArrayKey)
        var slidingValues = [String]()
        if values != nil, let values = values as? [String] {
            slidingValues = values.suffix(512)
        }
        slidingValues.append(DateUtils.getExtendedAbsTimeSpanString(timeStamp: Double(Date().timeIntervalSince1970)) + "|" + value)
        shared.set(slidingValues, forKey: debugArrayKey)
    }
}

import Foundation
public extension UserDefaults {
    static var hasExtensionAttemptedToSend = "hasExtensionAttemptedToSend"
    static var hasSavedKeyToKeychain = "hasSavedKeyToKeychain"
    static var upgradedKeychainEntry = "upgradedKeychainEntry_"
    static var debugArrayKey = "notify-fetch-info"
    static var mainIoRunningKey = "mainIoRunning"
    static var nseFetchingKey = "nseFetching"

    static var shared: UserDefaults? {
        return UserDefaults(suiteName: "group.chat.delta.ios")
    }

    static var mainIoRunning: Bool {
        return shared?.bool(forKey: mainIoRunningKey) ?? false
    }

    static func setMainIoRunning(_ value: Bool = true) {
        UserDefaults.pushToDebugArray(value ? "▶️" : "⏸️")
        shared?.setValue(value, forKey: mainIoRunningKey)
    }

    /// Check if we are currently fetching using the Notification Service Extension. Never returns true for more than 30 seconds.
    static var nseFetching: Bool {
        guard let shared else { return false }
        let until = Date(timeIntervalSince1970: shared.double(forKey: nseFetchingKey))

        if until > Date().addingTimeInterval(30) {
            // user changed their system clock so we reset nse fetching date
            setNseFetching(for: 30)
        }

        return until > Date()
    }

    /// Set the amount of seconds for which the Notification Service Extension could be fetching. Call setNseFetchingDone when done.
    static func setNseFetching(for seconds: Double) {
        assert(0...30 ~= seconds, "Don't set NSE fetching for more than 30 seconds")
        shared?.set(Date().timeIntervalSince1970 + seconds, forKey: nseFetchingKey)
    }

    static func setNseFetchingDone() {
        shared?.set(nil, forKey: nseFetchingKey)
    }

    static func pushToDebugArray(_ value: String) {
        guard let shared else { return }
        let values = shared.array(forKey: debugArrayKey)
        var slidingValues = [String]()
        if values != nil, let values = values as? [String] {
            slidingValues = values.suffix(512)
        }
        slidingValues.append(DateUtils.getExtendedAbsTimeSpanString(timeStamp: Date().timeIntervalSince1970) + "|" + value)
        shared.set(slidingValues, forKey: debugArrayKey)
    }
}

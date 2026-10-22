import Foundation
import Combine

public extension UserDefaults {
    static var hasExtensionAttemptedToSend = "hasExtensionAttemptedToSend"
    static var hasSavedKeyToKeychain = "hasSavedKeyToKeychain"
    static var upgradedKeychainEntry = "upgradedKeychainEntry_"
    static var debugArrayKey = "notify-fetch-info"
    static var incomingCallPayloadKey = "incomingCallPayload"
    static var appPickerUrl = "appPickerUrl"
    static var defaultAppPickerUrlString = "https://webxdc.org/apps/"

    static var shared: SharedUserDefaults = {
        return SharedUserDefaults(suiteName: "group.chat.delta.ios") ?? {
            assertionFailure("Failed to init UserDefaults for suite")
            return SharedUserDefaults()
        }()
    }()

    static func getAppPickerUrlString() -> String {
        UserDefaults.standard.string(forKey: appPickerUrl) ?? defaultAppPickerUrlString
    }

    static func setAppPickerUrlString(_ url: String?) {
        if let url {
            UserDefaults.standard.set(url, forKey: appPickerUrl)
        } else {
            UserDefaults.standard.removeObject(forKey: appPickerUrl)
        }
    }
}

public class SharedUserDefaults: UserDefaults {
    private static var mainIoRunningKey = "mainIoRunning"

    public var mainIoRunning: Bool {
        get { bool(forKey: Self.mainIoRunningKey) }
        set {
            pushToDebugArray(newValue ? "▶️" : "⏸️")
            setValue(newValue, forKey: Self.mainIoRunningKey)
        }
    }

    private static var nseFetchingKey = "nseFetching"

    /// Check if we are currently fetching using the Notification Service Extension. Never returns true for more than 30 seconds.
    public func isNseFetching() -> Bool {
        let until = Date(timeIntervalSince1970: double(forKey: Self.nseFetchingKey))

        if until > Date().addingTimeInterval(30) {
            // user changed their system clock so we reset nse fetching date
            setNseFetching(for: 30)
        }

        return until > Date()
    }

    /// Set the amount of seconds for which the Notification Service Extension could be fetching. Call setNseFetchingDone when done.
    public func setNseFetching(for seconds: Double) {
        assert(0...30 ~= seconds, "Don't set NSE fetching for more than 30 seconds")
        set(Date().timeIntervalSince1970 + seconds, forKey: Self.nseFetchingKey)
    }

    public func setNseFetchingDone() {
        set(nil, forKey: Self.nseFetchingKey)
    }

    public func pushToDebugArray(_ value: String) {
        let values = array(forKey: Self.debugArrayKey)
        var slidingValues = [String]()
        if values != nil, let values = values as? [String] {
            slidingValues = values.suffix(512)
        }
        slidingValues.append(DateUtils.getExtendedAbsTimeSpanString(timeStamp: Date().timeIntervalSince1970) + "|" + value)
        set(slidingValues, forKey: Self.debugArrayKey)
    }
}

public protocol PublishingUserDefaults: AnyObject {}
public extension PublishingUserDefaults {
    func publisher<T: Equatable>(for keyPath: KeyPath<Self, T>) -> AnyPublisher<T, Never> {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: self)
            .map { _ in self[keyPath: keyPath] }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
extension UserDefaults: PublishingUserDefaults {}

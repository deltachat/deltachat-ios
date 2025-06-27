import notify

@objc public enum DarwinNotification: Int {
    case appRunningQuestion
    case appRunningConfirmation
    case nseFetchingQuestion
    case nseFetchingConfirmation

    var name: String {
        switch self {
        case .appRunningQuestion: "chat.delta.app_running_question"
        case .appRunningConfirmation: "chat.delta.app_running_confirmation"
        case .nseFetchingQuestion: "chat.delta.nse_fetching_question"
        case .nseFetchingConfirmation: "chat.delta.nse_fetching_confirmation"
        }
    }
}

public class DarwinNotificationCenter {
    public static var current = DarwinNotificationCenter()

    private init() {}

    private var dispatchTable: [DarwinNotification: [ObjectIdentifier: (DarwinNotification) -> Void]] = [:]
    private var actingObservers: [ObjectIdentifier: DarwinNotificationCenterActingObserver] = [:]
    private var notifyTokens: [DarwinNotification: Int32] = [:]

    /// Adds an entry to the notification center to receive notifications that passed to the provided block.
    ///
    /// - Parameters:
    ///     - notification: The notification to register for delivery to the observer.
    ///     - callback:
    ///         The closure that executes when receiving a notification.
    ///         The notification center copies the closure. The notification center strongly holds the copied closure until you remove the observer registration.
    ///         The closure takes one argument: the notification.
    /// - Returns: An opaque object to act as the observer. Notification center strongly holds this return value until you remove the observer registration.
    public func addObserver(for notification: DarwinNotification, using callback: @escaping (DarwinNotification) -> Void) -> AnyObject {
        let actingObserver = DarwinNotificationCenterActingObserver(callback: callback)
        actingObservers[ObjectIdentifier(actingObserver)] = actingObserver
        addObserver(actingObserver, selector: #selector(DarwinNotificationCenterActingObserver.callback), for: notification)
        return actingObserver
    }

    /// Adds an entry to the notification center to call the provided selector with the notification.
    ///
    /// - Parameters:
    ///     - observer: An object to register as an observer.
    ///     - selector: A selector that specifies the message the receiver sends observer to alert it to the notification posting. The method that selector specifies must have one and only one argument (an instance of DarwinNotification).
    ///     - notification: The notification to register for delivery to the observer.
    public func addObserver(_ observer: AnyObject, selector: Selector, for notification: DarwinNotification, on queue: DispatchQueue = .main) {
        // Start observing if this is the first observer with this notification name
        if dispatchTable[notification, default: [:]].isEmpty {
            notify_register_dispatch(notification.name, &notifyTokens[notification, default: NOTIFY_TOKEN_INVALID], queue) { _ in
                DarwinNotificationCenter.current.dispatchTable[notification]?.values.forEach { $0(notification) }
            }
        }

        // Save observer
        let id = ObjectIdentifier(observer)
        dispatchTable[notification, default: [:]][id] = { [weak observer] notification in
            if let observer {
                _ = observer.perform(selector, with: notification)
            } else { // observer has been deallocated so remove it
                Self.current.removeObserver(id: id, name: notification)
            }
        }
    }

    /// Removes all entries specifying an observer from the notification center’s dispatch table.
    public func removeObserver(_ observer: AnyObject) {
        let id = ObjectIdentifier(observer)
        dispatchTable.filter { $0.value[id] != nil }.keys.forEach { subscribedNotification in
            removeObserver(id: id, name: subscribedNotification)
        }
    }

    /// Removes matching entries from the notification center’s dispatch table.
    public func removeObserver(_ observer: AnyObject, name notification: DarwinNotification) {
        removeObserver(id: ObjectIdentifier(observer), name: notification)
    }

    private func removeObserver(id: ObjectIdentifier, name notification: DarwinNotification) {
        // prevent leak in the case where user might strongly reference the acting observer inside the callback
        actingObservers[id]?._callback = nil
        actingObservers[id] = nil
        dispatchTable[notification]?[id] = nil
        if dispatchTable[notification, default: [:]].isEmpty, let token = notifyTokens[notification] {
            notify_cancel(token)
            notifyTokens[notification] = nil
        }
    }

    /// Posts a given notification to the notification center.
    public func post(_ notification: DarwinNotification) {
        notify_post(notification.name)
    }
}

extension DarwinNotificationCenter {
    public func didReplyBlocking(_ reply: DarwinNotification, to: DarwinNotification, timeout: DispatchTime) -> Bool {
        let group = DispatchGroup()
        group.enter()
        let observer = addObserver(for: reply) { _ in group.leave() }
        post(to)
        let result = group.wait(timeout: timeout)
        removeObserver(observer)
        return result == .success
    }

    public func didReply(_ reply: DarwinNotification, to: DarwinNotification, timeout: DispatchTime) async -> Bool {
        await withCheckedContinuation { continuation in
            var didContinue = false
            let observer = addObserver(for: reply) { _ in
                guard !didContinue else { return }
                didContinue = true
                continuation.resume(returning: true)
            }
            post(to)
            DispatchQueue.main.asyncAfter(deadline: timeout) {
                DarwinNotificationCenter.current.removeObserver(observer)
                guard !didContinue else { return }
                didContinue = true
                continuation.resume(returning: false)
            }
        }
    }
}

/// An Acting Observer for subscribing to darwin notifications using a closure
private class DarwinNotificationCenterActingObserver {
    fileprivate var _callback: ((DarwinNotification) -> Void)?
    init(callback: @escaping (DarwinNotification) -> Void) {
        self._callback = callback
    }
    @objc func callback(notification: DarwinNotification) {
        _callback?(notification)
    }
}

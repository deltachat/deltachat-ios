import UserNotifications
import DcCore

class NotificationService: UNNotificationServiceExtension {
    let dcAccounts = DcAccounts.shared

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let bestAttemptContent = request.content
        func newNotificationContent() -> UNMutableNotificationContent {
            bestAttemptContent.mutableCopy() as? UNMutableNotificationContent ?? .init()
        }
        let nowTimestamp = Date().timeIntervalSince1970
        UserDefaults.pushToDebugArray("🤜")

        if UserDefaults.mainIoRunning {
            UserDefaults.pushToDebugArray("ABORT4_AS_MAIN_RUNS")
            contentHandler(silentNotification())
            return
        }
        UserDefaults.setNseFetching(for: 26)

        dcAccounts.openDatabase(writeable: false)
        let eventEmitter = dcAccounts.getEventEmitter()

        // Send the bestAttempt notification when memory is critical because the process will be killed
        // by the system soon and any notification is better than nothing.
        var exitedDueToCriticalMemory = false
        let memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .critical)
        memoryPressureSource.setEventHandler { [weak memoryPressureSource] in
            guard let memoryPressureSource, !memoryPressureSource.isCancelled else { return }
            memoryPressureSource.cancel()
            // Order of importance because we might crash very soon
            exitedDueToCriticalMemory = true
            UserDefaults.setNseFetching(for: 3)
            UserDefaults.pushToDebugArray("ERR5_LOW_MEM")
            contentHandler(bestAttemptContent)
        }
        memoryPressureSource.activate()

        guard dcAccounts.backgroundFetch(timeout: 25) && !exitedDueToCriticalMemory else {
            UserDefaults.pushToDebugArray("ERR3_CORE")
            UserDefaults.setNseFetchingDone()
            if !exitedDueToCriticalMemory {
                contentHandler(bestAttemptContent)
            }
            return
        }
        UserDefaults.setNseFetchingDone()
        memoryPressureSource.cancel()

        var notifications: [UNMutableNotificationContent] = []
        while true {
            guard let event = eventEmitter.getNextEvent() else { break }
            if event.id == DC_EVENT_ACCOUNTS_BACKGROUND_FETCH_DONE { break }
            if event.id == DC_EVENT_INCOMING_MSG {
                let dcContext = dcAccounts.get(id: event.accountId)
                let chat = dcContext.getChat(chatId: event.data1Int)
                let msg = dcContext.getMessage(id: event.data2Int)
                if let content = UNMutableNotificationContent(forMessage: msg, chat: chat, context: dcContext) {
                    notifications.append(content)
                }
            } else if event.id == DC_EVENT_INCOMING_REACTION {
                let dcContext = dcAccounts.get(id: event.accountId)
                let msg = dcContext.getMessage(id: event.data2Int)
                let chat = dcContext.getChat(chatId: msg.chatId)
                if let content = UNMutableNotificationContent(forReaction: event.data2String, from: event.data1Int, msg: msg, chat: chat, context: dcContext) {
                    notifications.append(content)
                }
            } else if event.id == DC_EVENT_INCOMING_WEBXDC_NOTIFY {
                let dcContext = dcAccounts.get(id: event.accountId)
                let msg = dcContext.getMessage(id: event.data2Int)
                let chat = dcContext.getChat(chatId: msg.chatId)
                if let content = UNMutableNotificationContent(forWebxdcNotification: event.data2String, msg: msg, chat: chat, context: dcContext) {
                    notifications.append(content)
                }
            }
        }

        // Queue all notifications
        for notification in notifications {
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: notification, trigger: nil)
            UNUserNotificationCenter.current().add(req) { error in
                if error != nil {
                    UserDefaults.pushToDebugArray("ERR6_UNUNC")
                }
            }
        }

        // This silent notification updates the badge number
        let silentNotification = silentNotification()
        silentNotification.badge = dcAccounts.getFreshMessageCount() as NSNumber
        dcAccounts.closeDatabase()
        if notifications.isEmpty {
            UserDefaults.pushToDebugArray(String(format: "OK3 %.3fs", Date().timeIntervalSince1970 - nowTimestamp))
        } else {
            UserDefaults.shared?.set(true, forKey: UserDefaults.hasExtensionAttemptedToSend) // force UI updates in case app was suspended
            UserDefaults.pushToDebugArray(String(format: "OK2 %.3fs", Date().timeIntervalSince1970 - nowTimestamp))
        }
        contentHandler(silentNotification)
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.

        // For Delta Chat, it is just fine to do nothing - assume eg. bad network or mail servers not reachable,
        // then a "You have new messages" is the best that can be done.
        UserDefaults.pushToDebugArray("ERR4_TIME")
        UserDefaults.setNseFetchingDone()
    }

    /// Do not show anything; requires `com.apple.developer.usernotifications.filtering` entitlement
    private func silentNotification() -> UNMutableNotificationContent {
        UNMutableNotificationContent()
    }
}

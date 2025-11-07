import UserNotifications
import CallKit
import DcCore

class NotificationService: UNNotificationServiceExtension {
    let dcAccounts = DcAccounts.shared

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        Task {
            await didReceive(request, withContentHandler: contentHandler)
        }
    }

    func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) async {
        let bestAttemptContent = request.content
        let nowTimestamp = Date().timeIntervalSince1970
        UserDefaults.pushToDebugArray("🤜")

        let dnc = DarwinNotificationCenter.current
        if await dnc.didReply(.appRunningConfirmation, to: .appRunningQuestion, timeout: .now() + .seconds(2)) {
            UserDefaults.pushToDebugArray("ABORT4_AS_MAIN_RUNS")
            contentHandler(silentNotification())
            return
        }
        if UserDefaults.nseFetching {
            UserDefaults.pushToDebugArray("ABORT5_AS_NSE_RUNS")
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
            guard let memoryPressureSource, !memoryPressureSource.isCancelled, !exitedDueToCriticalMemory else { return }
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
            } else if event.id == DC_EVENT_INCOMING_CALL {
                UserDefaults.pushToDebugArray("☎️")
                if #available(iOSApplicationExtension 14.5, *), canUseCallKit {
                    // reportNewIncomingVoIPPushPayload ends up in didReceiveIncomingPushWith in the main app
                    CXProvider.reportNewIncomingVoIPPushPayload([
                        "event_id": Int(DC_EVENT_INCOMING_CALL),
                        "account_id": event.accountId,
                        "message_id": event.data1Int,
                        "place_call_info": event.data2String,
                    ] as [String: Any]) { error in
                        if let error {
                            UserDefaults.pushToDebugArray("ERR6 " + error.localizedDescription)
                        } else {
                            UserDefaults.pushToDebugArray("OK2")
                        }
                    }
                } else if #unavailable(iOSApplicationExtension 14.5) {
                    let content = UNMutableNotificationContent()
                    let msg = dcAccounts.get(id: event.accountId).getMessage(id: event.data1Int)
                    content.title = "Incoming Call"
                    content.body = "Calls require iOS 14.5 or newer"
                    content.userInfo["account_id"] = event.accountId
                    content.userInfo["chat_id"] = msg.chatId
                    content.userInfo["message_id"] = msg.id
                    notifications.append(content)
                }
            } else if event.id == DC_EVENT_CALL_ENDED || event.id == DC_EVENT_INCOMING_CALL_ACCEPTED {
                UserDefaults.pushToDebugArray(event.id == DC_EVENT_CALL_ENDED ? "☎️ENDED" : "☎️ACCEPTED")
                if #available(iOSApplicationExtension 14.5, *), canUseCallKit {
                    // reportNewIncomingVoIPPushPayload ends up in didReceiveIncomingPushWith in the main app
                    CXProvider.reportNewIncomingVoIPPushPayload([
                        "event_id": Int(event.id),
                        "account_id": event.accountId,
                        "message_id": event.data1Int,
                    ] as [String: Any]) { error in
                        if let error {
                            UserDefaults.pushToDebugArray("ERR7 " + error.localizedDescription)
                        } else {
                            UserDefaults.pushToDebugArray("OK4")
                        }
                    }
                }
            }
        }

        // Queue all notifications
        for notification in notifications {
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: notification, trigger: nil)
            do {
                try await UNUserNotificationCenter.current().add(req)
            } catch {
                UserDefaults.pushToDebugArray("ERR6_UNUNC")
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

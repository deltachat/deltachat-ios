import UserNotifications
import DcCore

class NotificationService: UNNotificationServiceExtension {
    let dcAccounts = DcAccounts.shared

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let bestAttemptContent = request.content
        func newNotificationContent() -> UNMutableNotificationContent {
            bestAttemptContent.mutableCopy() as? UNMutableNotificationContent ?? .init()
        }
        let nowTimestamp = Double(Date().timeIntervalSince1970)
        UserDefaults.pushToDebugArray("🤜")

        if UserDefaults.mainIoRunning {
            UserDefaults.pushToDebugArray("ABORT4_AS_MAIN_RUNS")
            contentHandler(silenceNotification())
            return
        }
        UserDefaults.setNseFetching(for: 26)

        dcAccounts.openDatabase(writeable: false)
        let eventEmitter = dcAccounts.getEventEmitter()

        // Send the bestAttempt notification when memory is critical because the process will be killed
        // by the system soon and any notification is better than nothing.
        var exitedDueToCriticalMemory = false
        let memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .critical)
        memoryPressureSource.setEventHandler {
            // Order of importance because we might crash very soon
            contentHandler(bestAttemptContent)
            exitedDueToCriticalMemory = true
            UserDefaults.setNseFetching(for: 3)
            UserDefaults.pushToDebugArray("ERR5_LOW_MEM")
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

        var notifications: [UNMutableNotificationContent] = []
        while true {
            guard let event = eventEmitter.getNextEvent() else { break }
            if event.id == DC_EVENT_ACCOUNTS_BACKGROUND_FETCH_DONE { break }
            if event.id == DC_EVENT_INCOMING_MSG {
                let dcContext = dcAccounts.get(id: event.accountId)
                let chat = dcContext.getChat(chatId: event.data1Int)
                if !dcContext.isMuted() {
                    let msg = dcContext.getMessage(id: event.data2Int)
                    if !chat.isMuted || (chat.isGroup && msg.isReplyToSelf && dcContext.isMentionsEnabled) {
                        let sender = msg.getSenderName(dcContext.getContact(id: msg.fromContactId))
                        let notification = newNotificationContent()
                        if chat.isGroup {
                            notification.title = chat.name
                            notification.body = "\(sender): " + (msg.summary(chars: 80) ?? "")
                        } else {
                            notification.title = sender
                            notification.body = msg.summary(chars: 80) ?? ""
                        }
                        notification.userInfo["account_id"] = dcContext.id
                        notification.userInfo["chat_id"] = chat.id
                        notification.userInfo["message_id"] = msg.id
                        notification.threadIdentifier = "\(dcContext.id)-\(chat.id)"
                        notification.setRelevanceScore(for: chat)
                        notifications.append(notification)
                    }
                }
            } else if event.id == DC_EVENT_INCOMING_REACTION {
                let dcContext = dcAccounts.get(id: event.accountId)
                if !dcContext.isMuted() {
                    let msg = dcContext.getMessage(id: event.data2Int)
                    let chat = dcContext.getChat(chatId: msg.chatId)
                    if !chat.isMuted || (chat.isGroup && dcContext.isMentionsEnabled) {
                        let sender = dcContext.getContact(id: event.data1Int).displayName
                        let summary = (msg.summary(chars: 80) ?? "")
                        let notification = newNotificationContent()
                        notification.title = chat.name
                        notification.body = String.localized(stringID: "reaction_by_other", parameter: sender, event.data2String, summary)
                        notification.userInfo["account_id"] = dcContext.id
                        notification.userInfo["chat_id"] = chat.id
                        notification.userInfo["message_id"] = msg.id
                        notification.threadIdentifier = "\(dcContext.id)-\(chat.id)"
                        notification.setRelevanceScore(for: chat)
                        notifications.append(notification)
                    }
                }
            } else if event.id == DC_EVENT_INCOMING_WEBXDC_NOTIFY {
                let dcContext = dcAccounts.get(id: event.accountId)
                if !dcContext.isMuted() {
                    let msg = dcContext.getMessage(id: event.data2Int)
                    let chat = dcContext.getChat(chatId: msg.chatId)
                    if !chat.isMuted || (chat.isGroup && dcContext.isMentionsEnabled) {
                        let notification = newNotificationContent()
                        notification.title = chat.name
                        notification.body = msg.getWebxdcAppName() + ": " + event.data2String
                        notification.userInfo["account_id"] = dcContext.id
                        notification.userInfo["chat_id"] = chat.id
                        notification.userInfo["message_id"] = msg.id
                        notification.threadIdentifier = "\(dcContext.id)-\(chat.id)"
                        notification.setRelevanceScore(for: chat)
                        notifications.append(notification)
                    }
                }
            }
        }

        // Queue all but the last notification. The last notification will be sent through the callback closure.
        for notification in notifications.dropLast() {
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: notification, trigger: nil)
            UNUserNotificationCenter.current().add(req) { error in
                if error != nil {
                    UserDefaults.pushToDebugArray("ERR6")
                }
            }
        }
        notifications.last?.badge = dcAccounts.getFreshMessageCount() as NSNumber
        dcAccounts.closeDatabase()
        if notifications.isEmpty {
            UserDefaults.pushToDebugArray(String(format: "OK3 %.3fs", Double(Date().timeIntervalSince1970) - nowTimestamp))
        } else {
            UserDefaults.shared?.set(true, forKey: UserDefaults.hasExtensionAttemptedToSend) // force UI updates in case app was suspended
            UserDefaults.pushToDebugArray(String(format: "OK2 %.3fs", Double(Date().timeIntervalSince1970) - nowTimestamp))
        }
        contentHandler(notifications.last ?? silenceNotification())
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.

        // For Delta Chat, it is just fine to do nothing - assume eg. bad network or mail servers not reachable,
        // then a "You have new messages" is the best that can be done.
        UserDefaults.pushToDebugArray("ERR4_TIME")
        UserDefaults.setNseFetchingDone()
    }

    private func silenceNotification() -> UNMutableNotificationContent {
        if #available(iOS 13.3, *) {
            // do not show anything; requires `com.apple.developer.usernotifications.filtering` entitlement
            return UNMutableNotificationContent()
        } else {
            // do not play a sound at least
            let content = UNMutableNotificationContent()
            content.sound = nil
            content.title = String.localized("new_messages")
            content.body = String.localized("videochat_tap_to_open")
            return content
        }
    }
}

private extension UNMutableNotificationContent {
    func setRelevanceScore(for chat: DcChat) {
        guard #available(iOS 15, *) else { return }
        relevanceScore = switch true {
        case _ where chat.visibility == DC_CHAT_VISIBILITY_PINNED: 0.9
        case _ where chat.isMuted: 0.0
        case _ where chat.isGroup: 0.3
        default: 0.5
        }
    }
}

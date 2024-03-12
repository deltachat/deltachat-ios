import UserNotifications
import DcCore

class NotificationService: UNNotificationServiceExtension {
    let dcAccounts = DcAccounts.shared

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) else { return }

        if UserDefaults.mainAppRunning {
            contentHandler(silenceNotification(bestAttemptContent))
            return
        }
        UserDefaults.setNseFetching()

        // as we're mixing in notifications from accounts without PUSH and we cannot add multiple notifications,
        // it is best to move everything to the same thread - and set just no threadIdentifier

        dcAccounts.openDatabase(writeable: false)
        let eventEmitter = dcAccounts.getEventEmitter()

        if !dcAccounts.backgroundFetch(timeout: 25) {
            UserDefaults.setNseFetching(false)
            contentHandler(bestAttemptContent)
            return
        }
        UserDefaults.setNseFetching(false)

        var messageCount = 0
        var uniqueChats: [String: String] = [:]
        while true {
            guard let event = eventEmitter.getNextEvent() else { break }
            if event.id == DC_EVENT_ACCOUNTS_BACKGROUND_FETCH_DONE { break }
            if event.id == DC_EVENT_INCOMING_MSG {
                let dcContext = dcAccounts.get(id: event.accountId)
                let chat = dcContext.getChat(chatId: event.data1Int)
                if !UserDefaults.standard.bool(forKey: "notifications_disabled") && !chat.isMuted {
                    let msg = dcContext.getMessage(id: event.data2Int)
                    let sender = msg.getSenderName(dcContext.getContact(id: msg.fromContactId))
                    bestAttemptContent.title = chat.isGroup ? chat.name : sender
                    bestAttemptContent.body = (chat.isGroup ? "\(sender): " : "") + (msg.summary(chars: 80) ?? "")
                    bestAttemptContent.userInfo["account_id"] = dcContext.id
                    bestAttemptContent.userInfo["chat_id"] = chat.id
                    bestAttemptContent.userInfo["message_id"] = msg.id

                    uniqueChats["\(dcContext.id)-\(chat.id)"] = bestAttemptContent.title
                    messageCount += 1
                }
            }
        }

        if messageCount == 0 {
            dcAccounts.closeDatabase()
            contentHandler(silenceNotification(bestAttemptContent))
        } else {
            bestAttemptContent.badge = dcAccounts.getFreshMessageCount() as NSNumber
            dcAccounts.closeDatabase()
            if messageCount > 1 {
                bestAttemptContent.userInfo["message_id"] = nil
                if uniqueChats.count == 1 {
                    bestAttemptContent.body = String.localized(stringID: "n_messages", parameter: messageCount)
                } else {
                    bestAttemptContent.userInfo["open_as_overview"] = true // leaving chat_id as is removes the notification when one of the chats is opened (does not matter which)
                    bestAttemptContent.title = uniqueChats.values.joined(separator: ", ")
                    bestAttemptContent.body = String.localized(stringID: "n_messages_in_m_chats", parameter: messageCount, uniqueChats.count)
                }
            }
            if #available(iOS 15.0, *) {
                bestAttemptContent.relevanceScore = 1.0
            }
            UserDefaults.shared?.set(true, forKey: UserDefaults.hasExtensionAttemptedToSend) // force UI updates in case app was suspended
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.

        // For Delta Chat, it is just fine to do nothing - assume eg. bad network or mail servers not reachable,
        // then a "You have new messages" is the best that can be done.
        UserDefaults.setNseFetching(false)
    }

    private func silenceNotification(_ bestAttemptContent: UNMutableNotificationContent) -> UNMutableNotificationContent {
        // with `com.apple.developer.usernotifications.filtering` entitlement,
        // one can use `contentHandler(UNMutableNotificationContent())` to not display a notifcation
        bestAttemptContent.sound = nil
        bestAttemptContent.body = "No more relevant messages"
        if #available(iOS 15.0, *) {
            bestAttemptContent.interruptionLevel = .passive
            bestAttemptContent.relevanceScore = 0.0
        }
        return bestAttemptContent
    }
}

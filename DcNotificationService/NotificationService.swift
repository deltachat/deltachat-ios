import UserNotifications
import DcCore

class NotificationService: UNNotificationServiceExtension {
    let dcAccounts = DcAccounts.shared

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) else { return }

        dcAccounts.openDatabase(writeable: false)
        let eventEmitter = dcAccounts.getEventEmitter()
        if !dcAccounts.backgroundFetch(timeout: 25) {
            contentHandler(bestAttemptContent)
            return
        }

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

                    uniqueChats["\(dcContext.id)-\(chat.id)"] = bestAttemptContent.title
                    messageCount += 1
                }
            }
        }
        bestAttemptContent.badge = dcAccounts.getFreshMessageCount() as NSNumber
        dcAccounts.closeDatabase()

        if messageCount == 0 {
            let canSilenceContent = false
            if canSilenceContent {
                let silentContent = UNMutableNotificationContent()
                contentHandler(silentContent)
            } else {
                bestAttemptContent.sound = nil
                bestAttemptContent.body = "No more relevant messages"
                if #available(iOS 15.0, *) {
                    bestAttemptContent.interruptionLevel = .passive
                    bestAttemptContent.relevanceScore = 0.0
                }
                contentHandler(bestAttemptContent)
            }
        } else if messageCount == 1 {
            if #available(iOS 15.0, *) {
                bestAttemptContent.relevanceScore = 1.0
            }
            contentHandler(bestAttemptContent)
        } else {
            if uniqueChats.count == 1 {
                bestAttemptContent.body = "\(messageCount) messages"
            } else {
                bestAttemptContent.title = uniqueChats.values.joined(separator: ", ")
                bestAttemptContent.body = "\(messageCount) messages in \(uniqueChats.count) chats"
            }
            if #available(iOS 15.0, *) {
                bestAttemptContent.relevanceScore = 1.0
            }
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.

        // For Delta Chat, it is just fine to do nothing - assume eg. bad network or mail servers not reachable,
        // then a "You have new messages" is the best that can be done.
    }
}

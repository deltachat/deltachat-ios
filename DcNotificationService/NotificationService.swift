import UserNotifications
import DcCore

class NotificationService: UNNotificationServiceExtension {
    let dcAccounts = DcAccounts.shared
    var contentHandler: ((UNNotificationContent) -> Void)?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        guard let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) else { return }

        dcAccounts.openDatabase(writeable: false)
        let eventEmitter = dcAccounts.getEventEmitter()
        if !dcAccounts.backgroundFetch(timeout: 25) {
            contentHandler(bestAttemptContent)
            return
        }

        var messageCount = 0
        var uniqueChats: [String: Bool] = [:]
        while true {
            guard let event = eventEmitter.getNextEvent() else { break }
            if event.id == DC_EVENT_ACCOUNTS_BACKGROUND_FETCH_DONE { break }
            if event.id == DC_EVENT_INCOMING_MSG {
                let dcContext = dcAccounts.get(id: event.accountId)
                let chat = dcContext.getChat(chatId: event.data1Int)
                if !UserDefaults.standard.bool(forKey: "notifications_disabled") && !chat.isMuted {
                    messageCount += 1
                    uniqueChats["\(dcContext.id)-\(chat.id)"] = true

                    let msg = dcContext.getMessage(id: event.data2Int)
                    let contact = dcContext.getContact(id: msg.fromContactId)
                    bestAttemptContent.title = chat.isGroup ? chat.name : msg.getSenderName(contact)
                    bestAttemptContent.body = msg.summary(chars: 80) ?? ""
                }
            }
        }

        if messageCount == 0 {
            let silentContent = UNMutableNotificationContent()
            contentHandler(silentContent)
        } else if messageCount == 1 {
            contentHandler(bestAttemptContent)
        } else {
            if uniqueChats.count == 1 {
                bestAttemptContent.body = String.localized(stringID: "n_messages", count: messageCount)
            } else {
                bestAttemptContent.body = String.localizedStringWithFormat(String.localized("n_messages_in_m_chats"), messageCount, uniqueChats.count)
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

import UserNotifications
import DcCore

class NotificationService: UNNotificationServiceExtension {
    let dcAccounts = DcAccounts.shared

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) else { return }
        let nowTimestamp = Double(Date().timeIntervalSince1970)
        UserDefaults.pushToDebugArray("🤜")

        if UserDefaults.mainIoRunning {
            UserDefaults.pushToDebugArray("ABORT4")
            contentHandler(silenceNotification())
            return
        }
        UserDefaults.setNseFetching(for: 26)

        // as we're mixing in notifications from accounts without PUSH and we cannot add multiple notifications,
        // it is best to move everything to the same thread - and set just no threadIdentifier

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
            UserDefaults.pushToDebugArray("ERR5")
        }
        memoryPressureSource.activate()

        guard dcAccounts.backgroundFetch(timeout: 25) && !exitedDueToCriticalMemory else {
            UserDefaults.pushToDebugArray("ERR3")
            UserDefaults.setNseFetchingDone()
            if !exitedDueToCriticalMemory {
                contentHandler(bestAttemptContent)
            }
            return
        }
        UserDefaults.setNseFetchingDone()

        var messageCount = 0
        var reactionCount = 0
        var uniqueChats: [String: String] = [:]
        while true {
            guard let event = eventEmitter.getNextEvent() else { break }
            if event.id == DC_EVENT_ACCOUNTS_BACKGROUND_FETCH_DONE { break }
            if event.id == DC_EVENT_INCOMING_MSG {
                let dcContext = dcAccounts.get(id: event.accountId)
                let chat = dcContext.getChat(chatId: event.data1Int)
                if !dcContext.isMuted() && !chat.isMuted {
                    let msg = dcContext.getMessage(id: event.data2Int)
                    let sender = msg.getSenderName(dcContext.getContact(id: msg.fromContactId))
                    if chat.isGroup {
                        bestAttemptContent.title = chat.name
                        bestAttemptContent.body = "\(sender): " + (msg.summary(chars: 80) ?? "")
                    } else {
                        bestAttemptContent.title = sender
                        bestAttemptContent.body = msg.summary(chars: 80) ?? ""
                    }
                    bestAttemptContent.userInfo["account_id"] = dcContext.id
                    bestAttemptContent.userInfo["chat_id"] = chat.id
                    bestAttemptContent.userInfo["message_id"] = msg.id

                    uniqueChats["\(dcContext.id)-\(chat.id)"] = bestAttemptContent.title
                    messageCount += 1
                }
            } else if event.id == DC_EVENT_INCOMING_REACTION {
                let dcContext = dcAccounts.get(id: event.accountId)
                if !dcContext.isMuted() {
                    let msg = dcContext.getMessage(id: event.data2Int)
                    let chat = dcContext.getChat(chatId: msg.chatId)
                    if !chat.isMuted {
                        let sender = dcContext.getContact(id: event.data1Int).displayName
                        let summary = (msg.summary(chars: 80) ?? "")
                        bestAttemptContent.title = chat.name
                        bestAttemptContent.body = String.localized(stringID: "reaction_by_other", parameter: sender, event.data2String, summary)
                        bestAttemptContent.userInfo["account_id"] = dcContext.id
                        bestAttemptContent.userInfo["chat_id"] = chat.id
                        bestAttemptContent.userInfo["message_id"] = msg.id

                        uniqueChats["\(dcContext.id)-\(chat.id)"] = bestAttemptContent.title
                        reactionCount += 1
                    }
                }
            } else if event.id == DC_EVENT_INCOMING_WEBXDC_NOTIFY {
                let dcContext = dcAccounts.get(id: event.accountId)
                if !dcContext.isMuted() {
                    let msg = dcContext.getMessage(id: event.data2Int)
                    let chat = dcContext.getChat(chatId: msg.chatId)
                    if !chat.isMuted {
                        bestAttemptContent.title = chat.name
                        bestAttemptContent.body = msg.getWebxdcAppName() + ": " + event.data2String
                        bestAttemptContent.userInfo["account_id"] = dcContext.id
                        bestAttemptContent.userInfo["chat_id"] = chat.id
                        bestAttemptContent.userInfo["message_id"] = msg.id

                        uniqueChats["\(dcContext.id)-\(chat.id)"] = bestAttemptContent.title
                        messageCount += 1
                    }
                }
            }
        }

        if (messageCount + reactionCount) == 0 {
            dcAccounts.closeDatabase()
            UserDefaults.pushToDebugArray(String(format: "OK0 %.3fs", Double(Date().timeIntervalSince1970) - nowTimestamp))
            contentHandler(silenceNotification())
        } else {
            bestAttemptContent.badge = dcAccounts.getFreshMessageCount() as NSNumber
            dcAccounts.closeDatabase()
            if (messageCount + reactionCount) > 1 {
                bestAttemptContent.userInfo["message_id"] = nil

                if messageCount > 0 && reactionCount > 0 {
                    bestAttemptContent.body = String.localized(stringID: "n_messages", parameter: messageCount) 
                                     + ", " + String.localized(stringID: "n_reactions", parameter: reactionCount)
                } else if messageCount > 0 {
                    bestAttemptContent.body = String.localized(stringID: "n_messages", parameter: messageCount)
                } else {
                    bestAttemptContent.body = String.localized(stringID: "n_reactions", parameter: reactionCount)
                }

                if uniqueChats.count > 1 {
                    bestAttemptContent.userInfo["open_as_overview"] = true // leaving chat_id removes the notification when one of the chats is opened
                    bestAttemptContent.title = uniqueChats.values.joined(separator: ", ")
                }
            }
            if #available(iOS 15.0, *) {
                bestAttemptContent.relevanceScore = 1.0
            }
            UserDefaults.shared?.set(true, forKey: UserDefaults.hasExtensionAttemptedToSend) // force UI updates in case app was suspended
            UserDefaults.pushToDebugArray(String(format: "OK1 %d %.3fs", messageCount, Double(Date().timeIntervalSince1970) - nowTimestamp))
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.

        // For Delta Chat, it is just fine to do nothing - assume eg. bad network or mail servers not reachable,
        // then a "You have new messages" is the best that can be done.
        UserDefaults.pushToDebugArray("ERR4")
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

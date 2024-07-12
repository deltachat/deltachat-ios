import UIKit
import UserNotifications

extension Notification.Name {
    // Messages
    public static let messagesChanged = Notification.Name(rawValue: "eventMsgsChanged")
    public static let messageReadDeliveredFailedReaction = Notification.Name(rawValue: "messageReadDeliveredFailedReaction")
    public static let incomingMessage = Notification.Name(rawValue: "eventIncomingMsg")
    public static let incomingMessageOnAnyAccount = Notification.Name(rawValue: "eventIncomingMsgAnyAccount")
    public static let messagesNoticed = Notification.Name(rawValue: "eventMsgsNoticed")

    // Chats
    public static let chatModified = Notification.Name(rawValue: "eventChatModified")

    // Contacts
    public static let contactsChanged = Notification.Name(rawValue: "eventContactsChanged")

    // Progress
    public static let importExportProgress = Notification.Name(rawValue: "eventImexProgress")
    public static let configurationProgress = Notification.Name(rawValue: "eventConfigureProgress")

    public static let connectivityChanged = Notification.Name(rawValue: "eventConnectivityChanged")

    // Webxdc
    public static let webxdcStatusUpdate = Notification.Name(rawValue: "eventWebxdcStatusUpdate")
    public static let webxdcRealtimeDataReceived = Notification.Name(rawValue: "eventWebxdcRealtimeData")
}

public let eventEphemeralTimerModified =  Notification.Name(rawValue: "eventEphemeralTimerModified")

public class DcEventHandler {
    let dcAccounts: DcAccounts

    public init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
    }

    public func handleEvent(event: DcEvent) {
        let data1 = event.data1Int
        let data2 = event.data2Int
        let accountId = event.accountId

        if event.id >= DC_EVENT_ERROR && event.id <= 499 {
            logger.error("[\(accountId)] \(event.data2String)")
            return
        }

        switch event.id {

        case DC_EVENT_INFO:
            logger.info("[\(accountId)] \(event.data2String)")

        case DC_EVENT_WARNING:
            logger.warning("[\(accountId)] \(event.data2String)")

        case DC_EVENT_CONFIGURE_PROGRESS:
            logger.info("📡[\(accountId)] configure: \(Int(data1))")
            DispatchQueue.main.async {
                let done = Int(data1) == 1000

                NotificationCenter.default.post(name: .configurationProgress, object: nil, userInfo: [
                    "progress": Int(data1),
                    "error": Int(data1) == 0,
                    "done": done,
                    "errorMessage": event.data2String,
                ])

                if done {
                    UserDefaults.standard.set(true, forKey: Constants.Keys.deltachatUserProvidedCredentialsKey)
                    UserDefaults.standard.synchronize()
                }
            }

        case DC_EVENT_IMEX_PROGRESS:
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .importExportProgress, object: nil, userInfo: [
                    "progress": Int(data1),
                    "error": Int(data1) == 0,
                    "done": Int(data1) == 1000,
                    "errorMessage": self.dcAccounts.get(id: accountId).lastErrorString,
                ])
            }
        case DC_EVENT_MSGS_CHANGED:
            guard accountId == dcAccounts.getSelected().id else { return }

            logger.info("📡[\(accountId)] msgs changed: \(data1), \(data2)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .messagesChanged, object: nil, userInfo: [
                    "message_id": Int(data2),
                    "chat_id": Int(data1),
                ])
            }

        case DC_EVENT_REACTIONS_CHANGED, DC_EVENT_MSG_READ, DC_EVENT_MSG_DELIVERED, DC_EVENT_MSG_FAILED:
            guard accountId == dcAccounts.getSelected().id else { return }

            logger.info("📡[\(accountId)] msgs reaction/read/delivered/failed: \(data1), \(data2)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .messageReadDeliveredFailedReaction, object: nil, userInfo: [
                    "message_id": Int(data2),
                    "chat_id": Int(data1),
                ])
            }

        case DC_EVENT_MSGS_NOTICED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .messagesNoticed, object: nil, userInfo: [
                    "chat_id": Int(data1),
                ])
            }

        case DC_EVENT_CHAT_MODIFIED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] chat modified: \(data1)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .chatModified, object: nil, userInfo: [
                    "chat_id": Int(data1),
                ])
            }
        case DC_EVENT_CHAT_EPHEMERAL_TIMER_MODIFIED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] ephemeral timer modified: \(data1)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: eventEphemeralTimerModified, object: nil, userInfo: [
                    "chat_id": Int(data1),
                ])
            }

        case DC_EVENT_INCOMING_MSG:
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .incomingMessageOnAnyAccount, object: nil)
            }
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] incoming message \(data2)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .incomingMessage, object: nil, userInfo: [
                    "message_id": Int(data2),
                    "chat_id": Int(data1),
                ])
            }

        case DC_EVENT_CONTACTS_CHANGED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] contact changed: \(data1)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .contactsChanged, object: nil, userInfo: [
                    "contact_id": Int(data1)
                ])
            }

        case DC_EVENT_CONNECTIVITY_CHANGED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] connectivity changed")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .connectivityChanged, object: nil)
            }

        case DC_EVENT_ACCOUNTS_BACKGROUND_FETCH_DONE:
            if let sem = dcAccounts.fetchSemaphore {
                sem.signal()
            }

        case DC_EVENT_WEBXDC_STATUS_UPDATE:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] webxdc update")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .webxdcStatusUpdate, object: nil, userInfo: [
                    "message_id": Int(data1),
                ])
            }

        case DC_EVENT_WEBXDC_REALTIME_DATA:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .webxdcRealtimeDataReceived, object: nil, userInfo: [
                    "message_id": Int(data1),
                    "data": event.data2Data,
                ])
            }

        default:
            break
        }
    }

}

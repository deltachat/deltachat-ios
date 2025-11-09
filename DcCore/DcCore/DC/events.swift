import UIKit
import UserNotifications

public enum Event {
    // Messages
    public static let messagesChanged = Notification.Name(rawValue: "messagesChanged")
    public static let messageReadDeliveredFailedReaction = Notification.Name(rawValue: "messageReadDeliveredFailedReaction")
    public static let incomingMessage = Notification.Name(rawValue: "incomingMessage")
    public static let incomingMessageOnAnyAccount = Notification.Name(rawValue: "incomingMessageOnAnyAccount")
    public static let incomingReaction = Notification.Name(rawValue: "incomingReaction")
    public static let incomingWebxdcNotify = Notification.Name(rawValue: "incomingWebxdcNotify")
    public static let messagesNoticed = Notification.Name(rawValue: "messagesNoticed")

    // Chats
    public static let chatModified = Notification.Name(rawValue: "chatModified")

    // Contacts
    public static let contactsChanged = Notification.Name(rawValue: "contactsChanged")

    // Progress
    public static let importExportProgress = Notification.Name(rawValue: "importExportProgress")
    public static let configurationProgress = Notification.Name(rawValue: "configurationProgress")

    public static let connectivityChanged = Notification.Name(rawValue: "connectivityChanged")

    // Webxdc
    public static let webxdcStatusUpdate = Notification.Name(rawValue: "webxdcStatusUpdate")
    public static let webxdcRealtimeDataReceived = Notification.Name(rawValue: "webxdcRealtimeDataReceived")

    public static let ephemeralTimerModified =  Notification.Name(rawValue: "ephemeralTimerModified")
    public static let incomingCall = Notification.Name(rawValue: "incomingCall")
    public static let incomingCallAccepted = Notification.Name(rawValue: "incomingCallAccepted")
    public static let outgoingCallAccepted = Notification.Name(rawValue: "outgoingCallAccepted")
    public static let callEnded = Notification.Name(rawValue: "callEnded")
    
    public static let relayHelperDidChange = Notification.Name(rawValue: "relayHelperDidChange")
}


public class DcEventHandler {
    let dcAccounts: DcAccounts

    public init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
    }

    public func handleEvent(event: DcEvent) {
        let data1 = event.data1Int
        let data2 = event.data2Int
        let accountId = event.accountId

        switch event.id {

        case DC_EVENT_ERROR, DC_EVENT_ERROR_SELF_NOT_IN_GROUP:
            logger.error("[\(accountId)] \(event.data2String)")

        case DC_EVENT_INFO:
            logger.info("[\(accountId)] \(event.data2String)")

        case DC_EVENT_WARNING:
            logger.warning("[\(accountId)] \(event.data2String)")

        case DC_EVENT_CONFIGURE_PROGRESS:
            logger.info("📡[\(accountId)] configure: \(Int(data1))")
            
            let done = Int(data1) == 1000
            
            NotificationCenter.default.post(name: Event.configurationProgress, object: nil, userInfo: [
                "progress": Int(data1),
                "error": Int(data1) == 0,
                "done": done,
                "errorMessage": event.data2String,
            ])
            
            if done {
                UserDefaults.standard.set(true, forKey: Constants.Keys.deltachatUserProvidedCredentialsKey)
            }
            
        case DC_EVENT_IMEX_PROGRESS:
            NotificationCenter.default.post(name: Event.importExportProgress, object: nil, userInfo: [
                "progress": Int(data1),
                "error": Int(data1) == 0,
                "done": Int(data1) == 1000,
                "errorMessage": self.dcAccounts.get(id: accountId).lastErrorString,
            ])

        case DC_EVENT_MSGS_CHANGED:
            guard accountId == dcAccounts.getSelected().id else { return }

            logger.info("📡[\(accountId)] msgs changed: \(data1), \(data2)")
            
            NotificationCenter.default.post(name: Event.messagesChanged, object: nil, userInfo: [
                "message_id": Int(data2),
                "chat_id": Int(data1),
            ])

        case DC_EVENT_REACTIONS_CHANGED, DC_EVENT_MSG_READ, DC_EVENT_MSG_DELIVERED, DC_EVENT_MSG_FAILED:
            guard accountId == dcAccounts.getSelected().id else { return }

            logger.info("📡[\(accountId)] msgs reaction/read/delivered/failed: \(data1), \(data2)")

            NotificationCenter.default.post(name: Event.messageReadDeliveredFailedReaction, object: nil, userInfo: [
                "message_id": Int(data2),
                "chat_id": Int(data1),
            ])

        case DC_EVENT_MSGS_NOTICED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            
            NotificationCenter.default.post(name: Event.messagesNoticed, object: nil, userInfo: [
                "chat_id": Int(data1),
                "account_id": accountId
            ])

        case DC_EVENT_CHAT_MODIFIED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] chat modified: \(data1)")

            NotificationCenter.default.post(name: Event.chatModified, object: nil, userInfo: [
                "chat_id": Int(data1),
            ])

        case DC_EVENT_CHAT_EPHEMERAL_TIMER_MODIFIED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] ephemeral timer modified: \(data1)")

            NotificationCenter.default.post(name: Event.ephemeralTimerModified, object: nil, userInfo: [
                "chat_id": Int(data1),
            ])

        case DC_EVENT_INCOMING_MSG:
            
            NotificationCenter.default.post(name: Event.incomingMessageOnAnyAccount, object: nil, userInfo: [
                "message_id": Int(data2),
                "chat_id": Int(data1),
                "account_id": accountId
            ])
            
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] incoming message \(data2)")

            NotificationCenter.default.post(name: Event.incomingMessage, object: nil, userInfo: [
                "message_id": Int(data2),
                "chat_id": Int(data1),
                "account_id": accountId
            ])

        case DC_EVENT_INCOMING_REACTION:
            logger.info("📡[\(accountId)] incoming reaction")
            NotificationCenter.default.post(name: Event.incomingReaction, object: nil, userInfo: [
                "account_id": Int(accountId),
                "contact_id": Int(data1),
                "msg_id": Int(data2),
                "reaction": event.data2String
            ])

        case DC_EVENT_INCOMING_WEBXDC_NOTIFY:
            logger.info("📡[\(accountId)] incoming webxdc notify")
            NotificationCenter.default.post(name: Event.incomingWebxdcNotify, object: nil, userInfo: [
                "account_id": Int(accountId),
                "contact_id": Int(data1),
                "msg_id": Int(data2),
                "text": event.data2String
            ])

        case DC_EVENT_CONTACTS_CHANGED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] contact changed: \(data1)")
                
            NotificationCenter.default.post(name: Event.contactsChanged, object: nil, userInfo: [
                "contact_id": Int(data1)
            ])

        case DC_EVENT_CONNECTIVITY_CHANGED:
            logger.info("📡[\(accountId)] connectivity changed")
            NotificationCenter.default.post(name: Event.connectivityChanged, object: nil, userInfo: ["account_id": Int(accountId)])

        case DC_EVENT_ACCOUNTS_BACKGROUND_FETCH_DONE:
            if let sem = dcAccounts.fetchSemaphore {
                sem.signal()
            }

        case DC_EVENT_WEBXDC_STATUS_UPDATE:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] webxdc update")
            NotificationCenter.default.post(name: Event.webxdcStatusUpdate, object: nil, userInfo: [
                "message_id": Int(data1),
            ])

        case DC_EVENT_WEBXDC_REALTIME_DATA:
            if accountId != dcAccounts.getSelected().id {
                return
            }

            NotificationCenter.default.post(name: Event.webxdcRealtimeDataReceived, object: nil, userInfo: [
                "message_id": Int(data1),
                "data": event.data2Data,
            ])

        case DC_EVENT_INCOMING_CALL:
            logger.info("☎️ DC_EVENT_INCOMING_CALL(\(accountId),\(data1))")
            NotificationCenter.default.post(name: Event.incomingCall, object: nil, userInfo: [
                "account_id": Int(accountId),
                "message_id": Int(data1),
                "place_call_info": event.data2String,
            ])

        case DC_EVENT_INCOMING_CALL_ACCEPTED:
            logger.info("☎️ DC_EVENT_INCOMING_CALL_ACCEPTED(\(accountId),\(data1))")
            NotificationCenter.default.post(name: Event.incomingCallAccepted, object: nil, userInfo: [
                "account_id": Int(accountId),
                "message_id": Int(data1),
            ])

        case DC_EVENT_OUTGOING_CALL_ACCEPTED:
            logger.info("☎️ DC_EVENT_OUTGOING_CALL_ACCEPTED(\(accountId),\(data1))")
            NotificationCenter.default.post(name: Event.outgoingCallAccepted, object: nil, userInfo: [
                "account_id": Int(accountId),
                "message_id": Int(data1),
                "accept_call_info": event.data2String,
            ])

        case DC_EVENT_CALL_ENDED:
            logger.info("☎️ DC_EVENT_CALL_ENDED(\(accountId),\(data1))")
            NotificationCenter.default.post(name: Event.callEnded, object: nil, userInfo: [
                "account_id": Int(accountId),
                "message_id": Int(data1),
            ])

        default:
            break
        }
    }

}

import UIKit
import UserNotifications

public let eventMsgsChangedReadDeliveredFailed = Notification.Name(rawValue: "eventMsgsChangedReadDeliveredFailed")
public let eventIncomingMsg = Notification.Name(rawValue: "eventIncomingMsg")
public let eventIncomingMsgAnyAccount = Notification.Name(rawValue: "eventIncomingMsgAnyAccount")
public let eventImexProgress = Notification.Name(rawValue: "eventImexProgress")
public let eventConfigureProgress = Notification.Name(rawValue: "eventConfigureProgress")
public let eventSecureInviterProgress = Notification.Name(rawValue: "eventSecureInviterProgress")
public let eventContactsChanged = Notification.Name(rawValue: "eventContactsChanged")
public let eventChatModified = Notification.Name(rawValue: "eventChatModified")
public let eventEphemeralTimerModified =  Notification.Name(rawValue: "eventEphemeralTimerModified")
public let eventMsgsNoticed = Notification.Name(rawValue: "eventMsgsNoticed")
public let eventConnectivityChanged = Notification.Name(rawValue: "eventConnectivityChanged")
public let eventWebxdcStatusUpdate = Notification.Name(rawValue: "eventWebxdcStatusUpdate")
public let eventLocationChanged = Notification.Name(rawValue: "eventLocationChanged")

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

                NotificationCenter.default.post(name: eventConfigureProgress, object: nil, userInfo: [
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
                NotificationCenter.default.post(name: eventImexProgress, object: nil, userInfo: [
                    "progress": Int(data1),
                    "error": Int(data1) == 0,
                    "done": Int(data1) == 1000,
                    "errorMessage": self.dcAccounts.get(id: accountId).lastErrorString,
                ])
            }

        case DC_EVENT_MSGS_CHANGED, DC_EVENT_REACTIONS_CHANGED, DC_EVENT_MSG_READ, DC_EVENT_MSG_DELIVERED, DC_EVENT_MSG_FAILED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] msgs changed: \(data1), \(data2)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: eventMsgsChangedReadDeliveredFailed, object: nil, userInfo: [
                    "message_id": Int(data2),
                    "chat_id": Int(data1),
                ])
            }

        case DC_EVENT_MSGS_NOTICED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: eventMsgsNoticed, object: nil, userInfo: [
                    "chat_id": Int(data1),
                ])
            }

        case DC_EVENT_CHAT_MODIFIED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] chat modified: \(data1)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: eventChatModified, object: nil, userInfo: [
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
                NotificationCenter.default.post(name: eventIncomingMsgAnyAccount, object: nil)
            }
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] incoming message \(data2)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: eventIncomingMsg, object: nil, userInfo: [
                    "message_id": Int(data2),
                    "chat_id": Int(data1),
                ])
            }

        case DC_EVENT_SECUREJOIN_INVITER_PROGRESS:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] securejoin inviter: \(data1)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: eventSecureInviterProgress, object: nil, userInfo: [
                    "progress": Int(data2),
                    "error": Int(data2) == 0,
                    "done": Int(data2) == 1000,
                ])
            }

        case DC_EVENT_CONTACTS_CHANGED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] contact changed: \(data1)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: eventContactsChanged, object: nil, userInfo: [
                    "contact_id": Int(data1)
                ])
            }

        case DC_EVENT_CONNECTIVITY_CHANGED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] connectivity changed")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: eventConnectivityChanged, object: nil)
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
                NotificationCenter.default.post(name: eventWebxdcStatusUpdate, object: nil, userInfo: [
                    "message_id": Int(data1),
                ])
            }

        case DC_EVENT_LOCATION_CHANGED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] location changed for contact \(data1)")
            DispatchQueue.main.async {
                let nc = NotificationCenter.default
                nc.post(
                    name: eventLocationChanged,
                    object: nil,
                    userInfo: [
                        "contact_id": Int(data1),
                    ]
                )
            }

        default:
            break
        }
    }

}

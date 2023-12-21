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

public class DcEventHandler {
    let dcAccounts: DcAccounts

    public init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
    }

    public func handleEvent(event: DcEvent) {
        let id = event.id
        let data1 = event.data1Int
        let data2 = event.data2Int
        let accountId = event.accountId

        if id >= DC_EVENT_ERROR && id <= 499 {
            let s = event.data2String
            logger.error("📡[\(accountId)] \(s)")
            return
        }

        switch id {

        case DC_EVENT_INFO:
            let s = event.data2String
            logger.info("📡[\(accountId)] \(s)")

        case DC_EVENT_WARNING:
            let s = event.data2String
            logger.warning("📡[\(accountId)] \(s)")

        case DC_EVENT_CONFIGURE_PROGRESS:
            logger.info("📡[\(accountId)] configure: \(Int(data1))")
            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                let done = Int(data1) == 1000

                nc.post(
                    name: eventConfigureProgress,
                    object: nil,
                    userInfo: [
                        "progress": Int(data1),
                        "error": Int(data1) == 0,
                        "done": done,
                        "errorMessage": event.data2String,
                    ]
                )

                if done {
                    UserDefaults.standard.set(true, forKey: Constants.Keys.deltachatUserProvidedCredentialsKey)
                    UserDefaults.standard.synchronize()
                }
            }

        case DC_EVENT_IMEX_PROGRESS:
            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                nc.post(
                    name: eventImexProgress,
                    object: nil,
                    userInfo: [
                        "progress": Int(data1),
                        "error": Int(data1) == 0,
                        "done": Int(data1) == 1000,
                        "errorMessage": self.dcAccounts.get(id: accountId).lastErrorString,
                    ]
                )
            }

        case DC_EVENT_IMAP_CONNECTED, DC_EVENT_SMTP_CONNECTED:
            logger.info("📡[\(accountId)] network: \(event.data2String)")

        case DC_EVENT_MSGS_CHANGED, DC_EVENT_MSG_READ, DC_EVENT_MSG_DELIVERED, DC_EVENT_MSG_FAILED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] change: \(id)")

            let nc = NotificationCenter.default

            DispatchQueue.main.async {
                nc.post(
                    name: eventMsgsChangedReadDeliveredFailed,
                    object: nil,
                    userInfo: [
                        "message_id": Int(data2),
                        "chat_id": Int(data1),
                    ]
                )
            }

        case DC_EVENT_MSGS_NOTICED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                nc.post(
                    name: eventMsgsNoticed,
                    object: nil,
                    userInfo: [
                        "chat_id": Int(data1),
                    ]
                )
            }

        case DC_EVENT_CHAT_MODIFIED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] chat modified: \(id)")
            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                nc.post(
                    name: eventChatModified,
                    object: nil,
                    userInfo: [
                        "chat_id": Int(data1),
                    ]
                )
            }
        case DC_EVENT_CHAT_EPHEMERAL_TIMER_MODIFIED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] ephemeral timer modified: \(id)")
            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                nc.post(
                    name: eventEphemeralTimerModified,
                    object: nil,
                    userInfo: [
                        "chat_id": Int(data1),
                    ]
                )
            }

        case DC_EVENT_INCOMING_MSG:
            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                nc.post(name: eventIncomingMsgAnyAccount,
                        object: nil,
                        userInfo: nil)
            }
            
            if accountId != dcAccounts.getSelected().id {
                return
            }
            
            let userInfo = [
                "message_id": Int(data2),
                "chat_id": Int(data1),
            ]

            logger.info("📡[\(accountId)] incoming message \(userInfo)")
            DispatchQueue.main.async {
                nc.post(name: eventIncomingMsg,
                        object: nil,
                        userInfo: userInfo)
            }

        case DC_EVENT_SMTP_MESSAGE_SENT:
            logger.info("📡[\(accountId)] smtp sent: \(event.data2String)")

        case DC_EVENT_SECUREJOIN_INVITER_PROGRESS:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] securejoin inviter: \(data1)")

            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                nc.post(
                    name: eventSecureInviterProgress,
                    object: nil,
                    userInfo: [
                        "progress": Int(data2),
                        "error": Int(data2) == 0,
                        "done": Int(data2) == 1000,
                    ]
                )
            }

        case DC_EVENT_CONTACTS_CHANGED:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] contact changed: \(data1)")
            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                nc.post(
                    name: eventContactsChanged,
                    object: nil,
                    userInfo: [
                        "contact_id": Int(data1)
                    ]
                )
            }

        case DC_EVENT_CONNECTIVITY_CHANGED:
            if let sem = dcAccounts.fetchSemaphore, dcAccounts.isAllWorkDone() {
                sem.signal()
            }
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] connectivity changed")
            DispatchQueue.main.async {
                let nc = NotificationCenter.default
                nc.post(
                    name: eventConnectivityChanged,
                    object: nil,
                    userInfo: nil
                )
            }

        case DC_EVENT_WEBXDC_STATUS_UPDATE:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] webxdc update")
            DispatchQueue.main.async {
                let nc = NotificationCenter.default
                nc.post(
                    name: eventWebxdcStatusUpdate,
                    object: nil,
                    userInfo: [
                        "message_id": Int(data1),
                    ]
                )
            }

        default:
            break
        }
    }

}

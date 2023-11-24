import UIKit
import UserNotifications

public let dcNotificationChanged = Notification.Name(rawValue: "MrEventMsgsChanged")
public let dcNotificationIncoming = Notification.Name(rawValue: "MrEventIncomingMsg")
public let dcNotificationIncomingAnyAccount = Notification.Name(rawValue: "EventIncomingMsgAnyAccount")
public let dcNotificationImexProgress = Notification.Name(rawValue: "dcNotificationImexProgress")
public let dcNotificationConfigureProgress = Notification.Name(rawValue: "MrEventConfigureProgress")
public let dcNotificationSecureInviterProgress = Notification.Name(rawValue: "MrEventSecureInviterProgress")
public let dcNotificationContactChanged = Notification.Name(rawValue: "MrEventContactsChanged")
public let dcNotificationChatModified = Notification.Name(rawValue: "dcNotificationChatModified")
public let dcEphemeralTimerModified =  Notification.Name(rawValue: "dcEphemeralTimerModified")
public let dcMsgsNoticed = Notification.Name(rawValue: "dcMsgsNoticed")
public let dcNotificationConnectivityChanged = Notification.Name(rawValue: "dcNotificationConnectivityChanged")
public let dcNotificationWebxdcUpdate = Notification.Name(rawValue: "dcNotificationWebxdcUpdate")

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
            logger.info("📡[\(accountId)] configure progress: \(Int(data1)) \(Int(data2))")
            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                let done = Int(data1) == 1000

                nc.post(
                    name: dcNotificationConfigureProgress,
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
                    name: dcNotificationImexProgress,
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
                    name: dcNotificationChanged,
                    object: nil,
                    userInfo: [
                        "message_id": Int(data2),
                        "chat_id": Int(data1),
                        "date": Date(),
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
                    name: dcMsgsNoticed,
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
                    name: dcNotificationChatModified,
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
                    name: dcEphemeralTimerModified,
                    object: nil,
                    userInfo: [
                        "chat_id": Int(data1),
                    ]
                )
            }

        case DC_EVENT_INCOMING_MSG:
            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                nc.post(name: dcNotificationIncomingAnyAccount,
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
                nc.post(name: dcNotificationIncoming,
                        object: nil,
                        userInfo: userInfo)
            }

        case DC_EVENT_SMTP_MESSAGE_SENT:
            logger.info("smtp message sent: \(event.data2String)")

        case DC_EVENT_SECUREJOIN_INVITER_PROGRESS:
            if accountId != dcAccounts.getSelected().id {
                return
            }
            logger.info("📡[\(accountId)] securejoin inviter progress \(data1)")

            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                nc.post(
                    name: dcNotificationSecureInviterProgress,
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
                    name: dcNotificationContactChanged,
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
                    name: dcNotificationConnectivityChanged,
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
                    name: dcNotificationWebxdcUpdate,
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

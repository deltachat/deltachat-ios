import UIKit
import UserNotifications
import OSLog

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
        let dcContext = dcAccounts.get(id: event.accountId)

        if id >= DC_EVENT_ERROR && id <= 499 {
            os_log("🚨📡%d %@", log: .default, type: .fault, accountId, event.data2String)
            return
        }

        switch id {

        case DC_EVENT_INFO:
            os_log("ℹ️📡%d %@", log: .default, type: .info, accountId, event.data2String)

        case DC_EVENT_WARNING:
            os_log("⚠️📡%d %@", log: .default, type: .error, accountId, event.data2String)

        case DC_EVENT_CONFIGURE_PROGRESS:
            dcContext.maxConfigureProgress = max(dcContext.maxConfigureProgress, Int(data1))
            os_log("📡%d configure progress: %d %d", log: .default, type: .debug, accountId, Int(data1), Int(data2))
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
                        "errorMessage": dcContext.lastErrorString as Any,
                    ]
                )
            }

        case DC_EVENT_IMAP_CONNECTED:
            os_log("📡%d network imap connected: %@", log: .default, type: .info, accountId, event.data2String)

        case DC_EVENT_SMTP_CONNECTED:
            os_log("📡%d network smtp connected: %@", log: .default, type: .info, accountId, event.data2String)

        case DC_EVENT_MSGS_CHANGED, DC_EVENT_MSG_READ, DC_EVENT_MSG_DELIVERED, DC_EVENT_MSG_FAILED:
            os_log("📡%d msg change: %d %d", log: .default, type: .debug, accountId, Int(data2), Int(data1))
            if dcContext.id != dcAccounts.getSelected().id {
                return
            }
            
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
            if dcContext.id != dcAccounts.getSelected().id {
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
            os_log("📡%d chat modified: (chatid=%d)", log: .default, type: .debug, accountId, Int(data1))
            if dcContext.id != dcAccounts.getSelected().id {
                return
            }
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
            os_log("📡%d chat ephemeral timer modified: (chatid=%d)", log: .default, type: .debug, accountId, Int(data1))
            if dcContext.id != dcAccounts.getSelected().id {
                return
            }
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
            os_log("📡%d incoming msg: (chatid=%d, message_id=%d)", log: .default, type: .default, accountId, Int(data1), Int(data2))
            if dcContext.id != dcAccounts.getSelected().id {
                return
            }
            
            let userInfo = [
                "message_id": Int(data2),
                "chat_id": Int(data1),
            ]

            DispatchQueue.main.async {
                nc.post(name: dcNotificationIncoming,
                        object: nil,
                        userInfo: userInfo)
            }

        case DC_EVENT_SMTP_MESSAGE_SENT:
            os_log("📡%d network smtp msg sent: %@", log: .default, type: .info, accountId, event.data2String)

        case DC_EVENT_SECUREJOIN_INVITER_PROGRESS:
            os_log("📡%d securejoin inviter progress: %d", log: .default, type: .info, accountId, data1)
            if dcContext.id != dcAccounts.getSelected().id {
                return
            }

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
            os_log("📡%d contact changed: %d", log: .default, type: .info, accountId, data1)
            if dcContext.id != dcAccounts.getSelected().id {
                return
            }
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
            let connectivity = dcContext.getConnectivity()
            os_log("📡%d connectivity changed: %d", log: .default, type: .info, accountId, connectivity)
            if let sem = dcAccounts.fetchSemaphore, dcAccounts.isAllWorkDone() {
                sem.signal()
            }
            if dcContext.id != dcAccounts.getSelected().id {
                return
            }
            DispatchQueue.main.async {
                let nc = NotificationCenter.default
                nc.post(
                    name: dcNotificationConnectivityChanged,
                    object: nil,
                    userInfo: nil
                )
            }

        case DC_EVENT_WEBXDC_STATUS_UPDATE:
            os_log("📡%d webxdc update: (msg_id=%d)", log: .default, type: .info, accountId, Int(data1))
            if dcContext.id != dcAccounts.getSelected().id {
                return
            }
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

        case DC_EVENT_INCOMING_MSG_BUNCH:
            os_log("📡%d imap incoming msg bunch", log: .default, type: .default, accountId, id)
            
        default:
            os_log("📡%d unknown event: (event_id=%d)", log: .default, type: .info, accountId, id)
        }
    }

}

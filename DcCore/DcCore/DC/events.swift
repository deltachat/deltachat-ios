import UIKit
import UserNotifications

public let dcNotificationChanged = Notification.Name(rawValue: "MrEventMsgsChanged")
public let dcNotificationIncoming = Notification.Name(rawValue: "MrEventIncomingMsg")
public let dcNotificationImexProgress = Notification.Name(rawValue: "dcNotificationImexProgress")
public let dcNotificationConfigureProgress = Notification.Name(rawValue: "MrEventConfigureProgress")
public let dcNotificationSecureJoinerProgress = Notification.Name(rawValue: "MrEventSecureJoinerProgress")
public let dcNotificationSecureInviterProgress = Notification.Name(rawValue: "MrEventSecureInviterProgress")
public let dcNotificationViewChat = Notification.Name(rawValue: "MrEventViewChat")
public let dcNotificationContactChanged = Notification.Name(rawValue: "MrEventContactsChanged")
public let dcNotificationChatModified = Notification.Name(rawValue: "dcNotificationChatModified")
public let dcEphemeralTimerModified =  Notification.Name(rawValue: "dcEphemeralTimerModified")
public let dcMsgsNoticed = Notification.Name(rawValue: "dcMsgsNoticed")

public func handleEvent(event: DcEvent) {
    let id = event.id
    let data1 = event.data1Int
    let data2 = event.data2Int

    if id >= DC_EVENT_ERROR && id <= 499 {
        let s = event.data2String
        DcContext.shared.lastErrorString = s
        DcContext.shared.logger?.error("event: \(s)")
        return
    }

    switch id {

    case DC_EVENT_INFO:
        let s = event.data2String
        DcContext.shared.logger?.info("event: \(s)")

    case DC_EVENT_WARNING:
        let s = event.data2String
        DcContext.shared.lastWarningString = s
        DcContext.shared.logger?.warning("event: \(s)")

    case DC_EVENT_CONFIGURE_PROGRESS:
        DcContext.shared.maxConfigureProgress = max(DcContext.shared.maxConfigureProgress, Int(data1))
        DcContext.shared.logger?.info("configure progress: \(Int(data1)) \(Int(data2))")
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
                    "errorMessage": DcContext.shared.lastErrorString as Any,
                ]
            )
        }

    case DC_EVENT_IMAP_CONNECTED, DC_EVENT_SMTP_CONNECTED:
        DcContext.shared.logger?.warning("network: \(event.data2String)")

    case DC_EVENT_MSGS_CHANGED, DC_EVENT_MSG_READ, DC_EVENT_MSG_DELIVERED, DC_EVENT_MSG_FAILED:
        DcContext.shared.logger?.info("change: \(id)")

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
        let nc = NotificationCenter.default
        DispatchQueue.main.async {
            nc.post(
                name: dcMsgsNoticed,
                object: nil,
                userInfo: [
                    "chat_id": Int(data1),
                ]
            )

            let array = DcContext.shared.getFreshMessages()
            UIApplication.shared.applicationIconBadgeNumber = array.count
        }

    case DC_EVENT_CHAT_MODIFIED:
        DcContext.shared.logger?.info("chat modified: \(id)")
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
        DcContext.shared.logger?.info("chat ephemeral timer modified: \(id)")
        let nc = NotificationCenter.default
        DispatchQueue.main.async {
            nc.post(
                name: dcEphemeralTimerModified,
                object: nil,
                userInfo: nil
            )
        }

    case DC_EVENT_INCOMING_MSG:
        let nc = NotificationCenter.default
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
        DcContext.shared.logger?.info("network: \(event.data2String)")

    case DC_EVENT_MSG_DELIVERED:
        DcContext.shared.logger?.info("message delivered: \(data1)-\(data2)")

    case DC_EVENT_SECUREJOIN_INVITER_PROGRESS:
        DcContext.shared.logger?.info("securejoin inviter progress \(data1)")

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

    case DC_EVENT_SECUREJOIN_JOINER_PROGRESS:
        DcContext.shared.logger?.info("securejoin joiner progress \(data1)")
        let nc = NotificationCenter.default
        DispatchQueue.main.async {
            nc.post(
                name: dcNotificationSecureJoinerProgress,
                object: nil,
                userInfo: [
                    "contact_id": Int(data1),
                    "progress": Int(data2),
                    "error": Int(data2) == 0,
                    "done": Int(data2) == 1000,
                ]
            )
        }
    case DC_EVENT_CONTACTS_CHANGED:
        DcContext.shared.logger?.info("contact changed: \(data1)")
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

    default:
        DcContext.shared.logger?.warning("unknown event: \(id)")
    }
}

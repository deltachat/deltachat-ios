import UIKit
import UserNotifications

let dcNotificationChanged = Notification.Name(rawValue: "MrEventMsgsChanged")
let dcNotificationIncoming = Notification.Name(rawValue: "MrEventIncomingMsg")
let dcNotificationImexProgress = Notification.Name(rawValue: "dcNotificationImexProgress")
let dcNotificationConfigureProgress = Notification.Name(rawValue: "MrEventConfigureProgress")
let dcNotificationSecureJoinerProgress = Notification.Name(rawValue: "MrEventSecureJoinerProgress")
let dcNotificationSecureInviterProgress = Notification.Name(rawValue: "MrEventSecureInviterProgress")
let dcNotificationViewChat = Notification.Name(rawValue: "MrEventViewChat")
let dcNotificationContactChanged = Notification.Name(rawValue: "MrEventContactsChanged")

@_silgen_name("callbackSwift")

public func callbackSwift(event: CInt, data1: CUnsignedLong, data2: CUnsignedLong, data1String: UnsafePointer<Int8>, data2String: UnsafePointer<Int8>) {
    if event >= DC_EVENT_ERROR && event <= 499 {
        let s = String(cString: data2String)
        AppDelegate.lastErrorString = s
        logger.error("event: \(s)")
        return
    }

    switch event {

    case DC_EVENT_INFO:
        let s = String(cString: data2String)
        logger.info("event: \(s)")

    case DC_EVENT_WARNING:
        let s = String(cString: data2String)
        logger.warning("event: \(s)")

    case DC_EVENT_CONFIGURE_PROGRESS:
        logger.info("configure progress: \(Int(data1)) \(Int(data2))")
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
                    "errorMessage": AppDelegate.lastErrorString as Any,
                ]
            )

            if done {
                UserDefaults.standard.set(true, forKey: Constants.Keys.deltachatUserProvidedCredentialsKey)
                UserDefaults.standard.synchronize()
                AppDelegate.lastErrorString = nil
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
                    "errorMessage": AppDelegate.lastErrorString as Any,
                ]
            )
        }

    case DC_EVENT_IMAP_CONNECTED, DC_EVENT_SMTP_CONNECTED:
        logger.warning("network: \(String(cString: data2String))")

    case DC_EVENT_MSGS_CHANGED, DC_EVENT_MSG_READ, DC_EVENT_MSG_DELIVERED, DC_EVENT_MSG_FAILED:
        logger.info("change: \(event)")

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

            if !UserDefaults.standard.bool(forKey: "notifications_disabled") {
                let content = UNMutableNotificationContent()
                let msg = DcMsg(id: Int(data2))
                content.title = msg.fromContact.displayName
                content.body = msg.summary(chars: 40) ?? ""
                content.userInfo = userInfo
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

                let request = UNNotificationRequest(identifier: Constants.notificationIdentifier, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                logger.info("notifications: added \(content)")
            }

            let array = DcArray(arrayPointer: dc_get_fresh_msgs(mailboxPointer))
            UIApplication.shared.applicationIconBadgeNumber = array.count
        }

    case DC_EVENT_SMTP_MESSAGE_SENT:
        logger.info("network: \(String(cString: data2String))")

    case DC_EVENT_MSG_DELIVERED:
        logger.info("message delivered: \(data1)-\(data2)")

    case DC_EVENT_SECUREJOIN_INVITER_PROGRESS:
        logger.info("securejoin inviter progress \(data1)")

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
        logger.info("securejoin joiner progress \(data1)")
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
        logger.info("contact changed: \(data1)")
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
        logger.warning("unknown event: \(event)")
    }
}

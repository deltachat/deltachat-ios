import UIKit
import UserNotifications

let dcNotificationChanged = Notification.Name(rawValue: "MrEventMsgsChanged")
let dcNotificationStateChanged = Notification.Name(rawValue: "MrEventStateChanged")
let dcNotificationIncoming = Notification.Name(rawValue: "MrEventIncomingMsg")
let dcNotificationImexProgress = Notification.Name(rawValue: "dcNotificationImexProgress")
let dcNotificationConfigureProgress = Notification.Name(rawValue: "MrEventConfigureProgress")
let dcNotificationSecureJoinerProgress = Notification.Name(rawValue: "MrEventSecureJoinerProgress")
let dcNotificationSecureInviterProgress = Notification.Name(rawValue: "MrEventSecureInviterProgress")
let dcNotificationViewChat = Notification.Name(rawValue: "MrEventViewChat")

@_silgen_name("callbackSwift")

public func callbackSwift(event: CInt, data1: CUnsignedLong, data2: CUnsignedLong, data1String: UnsafePointer<Int8>, data2String: UnsafePointer<Int8>) -> UnsafePointer<Int8>? {
    switch event {

    case DC_EVENT_INFO:
        let s = String(cString: data2String)
        logger.info("event: \(s)")

    case DC_EVENT_WARNING:
        let s = String(cString: data2String)
        logger.warning("event: \(s)")

    case DC_EVENT_ERROR:
        let s = String(cString: data2String)
        AppDelegate.lastErrorDuringConfig = s
        logger.error("event: \(s)")

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
                    "errorMessage": AppDelegate.lastErrorDuringConfig as Any,
                ]
            )

            if done {
                UserDefaults.standard.set(true, forKey: Constants.Keys.deltachatUserProvidedCredentialsKey)
                UserDefaults.standard.synchronize()
                AppDelegate.lastErrorDuringConfig = nil
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
                    "errorMessage": AppDelegate.lastErrorDuringConfig as Any,
                ]
            )
        }

    case DC_EVENT_ERROR_NETWORK:
        let msg = String(cString: data2String)
        if data1 == 1 {
            AppDelegate.lastErrorDuringConfig = msg
            logger.error("network: \(msg)")
        } else {
            logger.warning("network: \(msg)")
        }

        let nc = NotificationCenter.default
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                nc.post(name: dcNotificationStateChanged,
                        object: nil,
                        userInfo: ["state": "offline"])
            }
        }

    case DC_EVENT_IMAP_CONNECTED, DC_EVENT_SMTP_CONNECTED:
        logger.warning("network: \(String(cString: data2String))")

        let nc = NotificationCenter.default
        DispatchQueue.main.async {
            nc.post(name: dcNotificationStateChanged,
                    object: nil,
                    userInfo: ["state": "online"])
        }

    case DC_EVENT_MSGS_CHANGED, DC_EVENT_MSG_READ, DC_EVENT_MSG_DELIVERED:
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

            let content = UNMutableNotificationContent()
            let msg = DcMsg(id: Int(data2))
            content.title = msg.fromContact.displayName
            content.body = msg.summary(chars: 40) ?? ""
            content.badge = 1
            content.userInfo = userInfo
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

            let request = UNNotificationRequest(identifier: Constants.notificationIdentifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            logger.info("notifications: added \(content)")
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

    case DC_EVENT_GET_STRING:
        var string = ""
        switch Int32(data1) {
        case DC_STR_NOMESSAGES: string = String.localized("chat_no_messages")
        case DC_STR_SELF: string = String.localized("self")
        case DC_STR_DRAFT: string = String.localized("draft")
        case DC_STR_VOICEMESSAGE: string = String.localized("voice_message")
        case DC_STR_DEADDROP: string = String.localized("chat_contact_request")
        case DC_STR_IMAGE: string = String.localized("image")
        case DC_STR_VIDEO: string = String.localized("video")
        case DC_STR_AUDIO: string = String.localized("audio")
        case DC_STR_FILE: string = String.localized("file")
        case DC_STR_STATUSLINE: string = String.localized("pref_default_status_text")
        case DC_STR_NEWGROUPDRAFT: string = String.localized("group_hello_draft")
        case DC_STR_MSGGRPNAME: string = String.localized("systemmsg_group_name_changed")
        case DC_STR_MSGGRPIMGCHANGED: string = String.localized("systemmsg_group_image_changed")
        case DC_STR_MSGADDMEMBER: string = String.localized("systemmsg_member_added")
        case DC_STR_MSGDELMEMBER: string = String.localized("systemmsg_member_removed")
        case DC_STR_MSGGROUPLEFT: string = String.localized("systemmsg_group_left")
        case DC_STR_GIF: string = String.localized("gif")
        case DC_STR_CANTDECRYPT_MSG_BODY: string = String.localized("systemmsg_cannot_decrypt")
        case DC_STR_READRCPT: string = String.localized("systemmsg_read_receipt_subject")
        case DC_STR_READRCPT_MAILBODY: string = String.localized("systemmsg_read_receipt_body")
        case DC_STR_MSGGRPIMGDELETED: string = String.localized("systemmsg_group_image_deleted")
        case DC_STR_CONTACT_VERIFIED: string = String.localized("contact_verified")
        case DC_STR_CONTACT_NOT_VERIFIED: string = String.localized("contact_not_verified")
        case DC_STR_CONTACT_SETUP_CHANGED: string = String.localized("contact_setup_changed")
        case DC_STR_ARCHIVEDCHATS: string = String.localized("chat_archived_chats_title")
        case DC_STR_AC_SETUP_MSG_SUBJECT: string = String.localized("autocrypt_asm_subject")
        case DC_STR_AC_SETUP_MSG_BODY: string = String.localized("autocrypt_asm_general_body")
        case DC_STR_SELFTALK_SUBTITLE: string = String.localized("chat_self_talk_subtitle")
        case DC_STR_CANNOT_LOGIN: string = String.localized("login_error_cannot_login")
        case DC_STR_SERVER_RESPONSE: string = String.localized("login_error_server_response")
        case DC_STR_MSGACTIONBYUSER: string = String.localized("systemmsg_action_by_user")
        case DC_STR_MSGACTIONBYME: string = String.localized("systemmsg_action_by_me")
        default: return nil
        }
        return UnsafePointer(strdup(string))

    default:
        logger.warning("unknown event: \(event)")
    }

    return nil
}

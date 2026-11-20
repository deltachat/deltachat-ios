import UserNotifications
import Intents

public extension UNNotificationContent {
    /// The limit for expanded notifications on iOS 14+.
    ///
    /// Note: The notification will be truncated at ~170 characters automatically by the system
    /// but the rest of the characters are visible by long-pressing the notification.
    private static var pushNotificationCharLimit = 250

    /// Initialiser that returns a notification for an incoming message. Returns nil if no notification should be sent (eg if chat is muted)
    static func forMessage(_ msg: DcMsg, chat: DcChat, context: DcContext) -> UNNotificationContent? {
        guard msg.id != 0 else { return nil }
        // call notifications should be fresh (a declined call is not fresh and needs no notification)
        guard msg.type != DC_MSG_CALL || msg.state == DC_STATE_IN_FRESH else { return nil }
        guard !context.isMuted() else { return nil }
        guard !chat.isMuted || (chat.isMultiUser && msg.isReplyToSelf && context.isMentionsEnabled) else { return nil }
        let content = UNMutableNotificationContent()
        let sender = msg.getSenderName(context.getContact(id: msg.fromContactId))
        content.title = chat.isMultiUser ? chat.name : sender
        content.body = msg.summary(chars: Self.pushNotificationCharLimit) ?? ""
        content.userInfo["account_id"] = context.id
        content.userInfo["chat_id"] = chat.id
        content.userInfo["message_id"] = msg.id
        content.userInfo["id"] = "\(context.id)-\(chat.id)-\(msg.id)"
        content.threadIdentifier = "\(context.id)-\(chat.id)"
        content.sound = .default
        content.setRelevanceScore(for: msg, in: chat, context: context)
        return content.updating(fromMessageIntentForMessage: msg, in: chat)
    }

    /// Initialiser that returns a notification for an incoming reaction. Returns nil if no notification should be sent (eg if chat is muted)
    static func forReaction(_ reaction: String, from contact: Int, msg: DcMsg, chat: DcChat, context: DcContext) -> UNNotificationContent? {
        guard !context.isMuted() else { return nil }
        guard !chat.isMuted || (chat.isMultiUser && !chat.isOutBroadcast && context.isMentionsEnabled) else { return nil }

        let contact = context.getContact(id: contact)
        let summary = msg.summary(chars: Self.pushNotificationCharLimit) ?? ""
        let content = UNMutableNotificationContent()
        content.title = chat.name
        content.body = String.localized(stringID: "reaction_by_other", parameter: contact.displayName, reaction, summary)
        content.userInfo["account_id"] = context.id
        content.userInfo["chat_id"] = chat.id
        content.userInfo["message_id"] = msg.id
        content.userInfo["id"] = "\(context.id)-\(chat.id)-\(msg.id)-reaction-\(contact.id)"
        content.threadIdentifier = "\(context.id)-\(chat.id)"
        content.sound = .default
        content.setRelevanceScore(for: msg, in: chat, context: context)
        return content.updating(fromMessageIntentForMessage: msg, in: chat)
    }

    /// Initialiser that returns a notification for an incoming webxdc notification. Returns nil if no notification should be sent (eg if chat is muted)
    static func forWebxdcNotification(_ notification: String, msg: DcMsg, chat: DcChat, context: DcContext) -> UNNotificationContent? {
        guard !context.isMuted() else { return nil }
        guard !chat.isMuted || (chat.isMultiUser && context.isMentionsEnabled) else { return nil }
        let content = UNMutableNotificationContent()
        content.title = chat.name
        content.body = msg.getWebxdcAppName() + ": " + notification
        content.userInfo["account_id"] = context.id
        content.userInfo["chat_id"] = chat.id
        content.userInfo["message_id"] = msg.id
        content.userInfo["id"] = "\(context.id)-\(chat.id)-\(msg.id)-update"
        content.threadIdentifier = "\(context.id)-\(chat.id)"
        content.sound = .default
        content.setRelevanceScore(for: msg, in: chat, context: context)
        return content.updating(fromMessageIntentForMessage: msg, in: chat)
    }

    static func forIncomingCallMsg(_ msg: DcMsg, hasVideo: Bool, chat: DcChat, context: DcContext) -> UNNotificationContent? {
        guard !context.isMuted(), !chat.isMuted, !canUseCallKit else { return nil }
        let content = UNMutableNotificationContent()
        let sender = msg.getSenderName(context.getContact(id: msg.fromContactId))
        content.title = chat.isMultiUser ? chat.name : sender
        content.body = .localized(hasVideo ? "video_call" : "audio_call")
        content.userInfo["account_id"] = context.id
        content.userInfo["chat_id"] = chat.id
        content.userInfo["message_id"] = msg.id
        content.userInfo["answer_call"] = true
        content.userInfo["id"] = "\(context.id)-\(chat.id)-\(msg.id)"
        content.threadIdentifier = "calls"
        content.sound = .default // TODO: Ring?
        content.setRelevanceScore(for: msg, in: chat, context: context)
        return content
    }

    func idOrRandomUUID() -> String {
        userInfo["id"] as? String ?? UUID().uuidString
    }

    private func updating(fromMessageIntentForMessage msg: DcMsg, in chat: DcChat) -> UNNotificationContent {
        do {
            return try updating(from: INSendMessageIntent(forChat: chat, msg: msg))
        } catch {
            logger.warning("Failed to add intent to notification with error: \(error)")
            return self
        }
    }
}

extension UNMutableNotificationContent {
    fileprivate func setRelevanceScore(for msg: DcMsg, in chat: DcChat, context: DcContext) {
        relevanceScore = switch true {
        case _ where chat.visibility == DC_CHAT_VISIBILITY_PINNED: 0.9
        case _ where chat.isMultiUser && context.isMentionsEnabled && msg.isReplyToSelf: 0.8
        case _ where chat.isMuted: 0.0
        case _ where chat.isMultiUser: 0.3
        default: 0.5
        }
    }
}

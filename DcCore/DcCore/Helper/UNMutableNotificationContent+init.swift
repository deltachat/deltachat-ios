import UserNotifications

public extension UNMutableNotificationContent {
    /// The limit for expanded notifications on iOS 14+.
    ///
    /// Note: The notification will be truncated at ~170 characters automatically by the system
    /// but the rest of the characters are visible by long-pressing the notification.
    private static var pushNotificationCharLimit = 250

    /// Initialiser that returns a notification for an incoming message. Returns nil if no notification should be sent (eg if chat is muted)
    convenience init?(forMessage msg: DcMsg, chat: DcChat, context: DcContext) {
        guard !context.isMuted() else { return nil }
        guard !chat.isMuted || (chat.isGroup && msg.isReplyToSelf && context.isMentionsEnabled) else { return nil }
        self.init()
        let sender = msg.getSenderName(context.getContact(id: msg.fromContactId))
        title = chat.isGroup ? chat.name : sender
        body = (chat.isGroup ? "\(sender): " : "") + (msg.summary(chars: Self.pushNotificationCharLimit) ?? "")
        userInfo["account_id"] = context.id
        userInfo["chat_id"] = chat.id
        userInfo["message_id"] = msg.id
        threadIdentifier = "\(context.id)-\(chat.id)"
        setRelevanceScore(for: msg, in: chat, context: context)
    }

    /// Initialiser that returns a notification for an incoming reaction. Returns nil if no notification should be sent (eg if chat is muted)
    convenience init?(forReaction reaction: String, from contact: Int, msg: DcMsg, chat: DcChat, context: DcContext) {
        guard !context.isMuted() else { return nil }
        guard !chat.isMuted || (chat.isGroup && context.isMentionsEnabled) else { return nil }
        let contact = context.getContact(id: contact)
        let summary = msg.summary(chars: Self.pushNotificationCharLimit) ?? ""
        self.init()
        title = chat.name
        body = String.localized(stringID: "reaction_by_other", parameter: contact.displayName, reaction, summary)
        userInfo["account_id"] = context.id
        userInfo["chat_id"] = chat.id
        userInfo["message_id"] = msg.id
        setRelevanceScore(for: msg, in: chat, context: context)
    }

    /// Initialiser that returns a notification for an incoming webxdc notification. Returns nil if no notification should be sent (eg if chat is muted)
    convenience init?(forWebxdcNotification notification: String, msg: DcMsg, chat: DcChat, context: DcContext) {
        guard !context.isMuted() else { return nil }
        guard !chat.isMuted || (chat.isGroup && context.isMentionsEnabled) else { return nil }
        self.init()
        title = chat.name
        body = msg.getWebxdcAppName() + ": " + notification
        userInfo["account_id"] = context.id
        userInfo["chat_id"] = chat.id
        userInfo["message_id"] = msg.id
        threadIdentifier = "\(context.id)-\(chat.id)"
        setRelevanceScore(for: msg, in: chat, context: context)
    }
}

extension UNMutableNotificationContent {
    fileprivate func setRelevanceScore(for msg: DcMsg, in chat: DcChat, context: DcContext) {
        guard #available(iOS 15, *) else { return }
        relevanceScore = switch true {
        case _ where chat.visibility == DC_CHAT_VISIBILITY_PINNED: 0.9
        case _ where chat.isGroup && context.isMentionsEnabled && msg.isReplyToSelf: 0.8
        case _ where chat.isMuted: 0.0
        case _ where chat.isGroup: 0.3
        default: 0.5
        }
    }
}

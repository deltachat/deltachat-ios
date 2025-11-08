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
        guard !chat.isMuted || (chat.isMultiUser && msg.isReplyToSelf && context.isMentionsEnabled) else { return nil }
        self.init()
        let sender = msg.getSenderName(context.getContact(id: msg.fromContactId))
        title = chat.isMultiUser ? chat.name : sender
        body = (chat.isMultiUser ? "\(sender): " : "") + (msg.summary(chars: Self.pushNotificationCharLimit) ?? "")
        userInfo["account_id"] = context.id
        userInfo["chat_id"] = chat.id
        userInfo["message_id"] = msg.id
        threadIdentifier = "\(context.id)-\(chat.id)"
        sound = .default
        setRelevanceScore(for: msg, in: chat, context: context)
    }

    /// Initialiser that returns a notification for an incoming reaction. Returns nil if no notification should be sent (eg if chat is muted)
    convenience init?(forReaction reaction: String, from contact: Int, msg: DcMsg, chat: DcChat, context: DcContext) {
        guard !context.isMuted() else { return nil }
        guard !chat.isMuted || (chat.isMultiUser && context.isMentionsEnabled) else { return nil }
        let contact = context.getContact(id: contact)
        let summary = msg.summary(chars: Self.pushNotificationCharLimit) ?? ""
        self.init()
        title = chat.name
        body = String.localized(stringID: "reaction_by_other", parameter: contact.displayName, reaction, summary)
        userInfo["account_id"] = context.id
        userInfo["chat_id"] = chat.id
        userInfo["message_id"] = msg.id
        sound = .default
        setRelevanceScore(for: msg, in: chat, context: context)
    }

    /// Initialiser that returns a notification for an incoming webxdc notification. Returns nil if no notification should be sent (eg if chat is muted)
    convenience init?(forWebxdcNotification notification: String, msg: DcMsg, chat: DcChat, context: DcContext) {
        guard !context.isMuted() else { return nil }
        guard !chat.isMuted || (chat.isMultiUser && context.isMentionsEnabled) else { return nil }
        self.init()
        title = chat.name
        body = msg.getWebxdcAppName() + ": " + notification
        userInfo["account_id"] = context.id
        userInfo["chat_id"] = chat.id
        userInfo["message_id"] = msg.id
        threadIdentifier = "\(context.id)-\(chat.id)"
        sound = .default
        setRelevanceScore(for: msg, in: chat, context: context)
    }

    convenience init?(forIncomingCall uuid: UUID, msg: DcMsg, chat: DcChat, context: DcContext) {
        guard !context.isMuted(), !chat.isMuted else { return nil }
        self.init()
        let sender = msg.getSenderName(context.getContact(id: msg.fromContactId))
        title = chat.isMultiUser ? chat.name : sender
        body = .localized("incoming_call")
        userInfo["account_id"] = context.id
        userInfo["chat_id"] = chat.id
        userInfo["message_id"] = msg.id
        userInfo["answer_call"] = uuid.uuidString
        threadIdentifier = "calls"
        sound = .default // TODO: Ring?
        setRelevanceScore(for: msg, in: chat, context: context)
    }

    convenience init?(forMissedCall: UUID, msg: DcMsg, chat: DcChat, context: DcContext) {
        guard !context.isMuted(), !chat.isMuted else { return nil }
        self.init()
        let sender = msg.getSenderName(context.getContact(id: msg.fromContactId))
        title = chat.isMultiUser ? chat.name : sender
        body = .localized("missed_call")
        userInfo["account_id"] = context.id
        userInfo["chat_id"] = chat.id
        userInfo["message_id"] = msg.id
        threadIdentifier = "calls"
        sound = .default
        setRelevanceScore(for: msg, in: chat, context: context)
    }
}

extension UNMutableNotificationContent {
    fileprivate func setRelevanceScore(for msg: DcMsg, in chat: DcChat, context: DcContext) {
        guard #available(iOS 15, *) else { return }
        relevanceScore = switch true {
        case _ where chat.visibility == DC_CHAT_VISIBILITY_PINNED: 0.9
        case _ where chat.isMultiUser && context.isMentionsEnabled && msg.isReplyToSelf: 0.8
        case _ where chat.isMuted: 0.0
        case _ where chat.isMultiUser: 0.3
        default: 0.5
        }
    }
}

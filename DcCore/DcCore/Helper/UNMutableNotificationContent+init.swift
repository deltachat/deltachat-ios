import UserNotifications
import Intents

public extension UNMutableNotificationContent {
    /// The limit for expanded notifications on iOS 14+.
    ///
    /// Note: The notification will be truncated at ~170 characters automatically by the system
    /// but the rest of the characters are visible by long-pressing the notification.
    private static var pushNotificationCharLimit = 250

    /// Initialiser that returns a notification for an incoming message. Returns nil if no notification should be sent (eg if chat is muted)
    convenience init?(forMessage msg: DcMsg, chat: DcChat, context: DcContext) {
        guard msg.id != 0 else { return nil } // invalid message
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

    /// Returns an iOS communication notification for an incoming message.
    ///
    /// The system uses the sender's image for one-to-one chats and the chat image
    /// for group chats. If the system cannot create the richer notification, keep
    /// the regular notification content instead.
    public func updatingForIncomingMessage(_ msg: DcMsg, chat: DcChat, context: DcContext) -> UNNotificationContent {
        guard #available(iOS 15.0, *) else { return self }

        let senderContact = context.getContact(id: msg.fromContactId)
        let senderName = msg.getSenderName(senderContact)
        let senderHandle = INPersonHandle(
            value: senderContact.email.isEmpty ? "deltachat-contact-\(context.id)-\(senderContact.id)" : senderContact.email,
            type: senderContact.email.isEmpty ? .unknown : .emailAddress
        )
        let sender = INPerson(
            personHandle: senderHandle,
            nameComponents: nil,
            displayName: senderName,
            image: senderContact.profileImage.flatMap { $0.pngData() }.map(INImage.init(imageData:)),
            contactIdentifier: nil,
            customIdentifier: "\(context.id)-\(senderContact.id)",
            isMe: false,
            suggestionType: .none
        )

        let isGroup = chat.isMultiUser
        let groupName = isGroup ? INSpeakableString(spokenPhrase: chat.name) : nil
        let recipients: [INPerson]? = isGroup ? chat.getContactIds(context)
            .filter { $0 != msg.fromContactId && $0 != Int(DC_CONTACT_ID_SELF) }
            .map { contactId in
                let contact = context.getContact(id: contactId)
                let handle = INPersonHandle(
                    value: contact.email.isEmpty ? "deltachat-contact-\(context.id)-\(contact.id)" : contact.email,
                    type: contact.email.isEmpty ? .unknown : .emailAddress
                )
                return INPerson(
                    personHandle: handle,
                    nameComponents: nil,
                    displayName: contact.displayName,
                    image: nil,
                    contactIdentifier: nil,
                    customIdentifier: "\(context.id)-\(contact.id)",
                    isMe: false,
                    suggestionType: .none
                )
            } : nil
        let intent = INSendMessageIntent(
            recipients: recipients,
            outgoingMessageType: .outgoingMessageText,
            content: body,
            speakableGroupName: groupName,
            conversationIdentifier: "\(context.id)-\(chat.id)",
            serviceName: nil,
            sender: sender,
            attachments: nil
        )

        if let groupImage = chat.profileImage.flatMap({ $0.pngData() }).map(INImage.init(imageData:)) {
            intent.setImage(groupImage, forParameterNamed: \.speakableGroupName)
        }

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        interaction.donate { error in
            if let error {
                logger.warning("Could not donate incoming message intent: \(error)")
            }
        }

        do {
            return try updating(from: intent)
        } catch {
            logger.warning("Could not create communication notification: \(error)")
            return self
        }
    }

    /// Initialiser that returns a notification for an incoming reaction. Returns nil if no notification should be sent (eg if chat is muted)
    convenience init?(forReaction reaction: String, from contact: Int, msg: DcMsg, chat: DcChat, context: DcContext) {
        guard !context.isMuted() else { return nil }
        guard !chat.isMuted || (chat.isMultiUser && !chat.isOutBroadcast && context.isMentionsEnabled) else { return nil }

        let contact = context.getContact(id: contact)
        let summary = msg.summary(chars: Self.pushNotificationCharLimit) ?? ""
        self.init()
        title = chat.name
        body = String.localized(stringID: "reaction_by_other", parameter: contact.displayName, reaction, summary)
        userInfo["account_id"] = context.id
        userInfo["chat_id"] = chat.id
        userInfo["message_id"] = msg.id
        threadIdentifier = "\(context.id)-\(chat.id)"
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

    convenience init?(forIncomingCallMsg msg: DcMsg, chat: DcChat, context: DcContext) {
        guard !context.isMuted(), !chat.isMuted, !canUseCallKit else { return nil }
        self.init()
        let sender = msg.getSenderName(context.getContact(id: msg.fromContactId))
        title = chat.isMultiUser ? chat.name : sender
        body = .localized("incoming_call")
        userInfo["account_id"] = context.id
        userInfo["chat_id"] = chat.id
        userInfo["message_id"] = msg.id
        userInfo["answer_call"] = true
        threadIdentifier = "calls"
        sound = .default // TODO: Ring?
        setRelevanceScore(for: msg, in: chat, context: context)
    }

    convenience init?(forMissedCallMsg msg: DcMsg, chat: DcChat, context: DcContext) {
        guard !context.isMuted(), !chat.isMuted, !canUseCallKit else { return nil }
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
        relevanceScore = switch true {
        case _ where chat.visibility == DC_CHAT_VISIBILITY_PINNED: 0.9
        case _ where chat.isMultiUser && context.isMentionsEnabled && msg.isReplyToSelf: 0.8
        case _ where chat.isMuted: 0.0
        case _ where chat.isMultiUser: 0.3
        default: 0.5
        }
    }
}

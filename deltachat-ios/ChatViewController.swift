//
//  ChatViewController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 08.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import MapKit
import MessageInputBar
import MessageKit
import UIKit

class ChatViewController: MessagesViewController {
    let outgoingAvatarOverlap: CGFloat = 17.5

    let chatId: Int
    let refreshControl = UIRefreshControl()
    var messageIds: [Int] = []
    var messageList: [Message] = []

    var msgChangedObserver: Any?
    var incomingMsgObserver: Any?

    var disableWriting = false

    init(chatId: Int) {
        self.chatId = chatId
        super.init(nibName: nil, bundle: nil)
        // self.getMessageIds()

        /*
         let chat = MRChat(id: chatId)
         let subtitle = dc_chat_get_subtitle(chat.chatPointer)!

         let s = String(validatingUTF8: subtitle)
         logger.info( s)
         */
    }

    @objc
    func loadMoreMessages() {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1) {
            self.getMessageIds()
            DispatchQueue.main.async {
                self.messageList = self.messageIds.map(self.idToMessage)
                self.messagesCollectionView.reloadDataAndKeepOffset()
                self.refreshControl.endRefreshing()
            }
        }
    }

    func loadFirstMessages() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.getMessageIds()
            DispatchQueue.main.async {
                self.messageList = self.messageIds.map(self.idToMessage)
                self.messagesCollectionView.reloadData()
                self.refreshControl.endRefreshing()
                self.messagesCollectionView.scrollToBottom(animated: false)
            }
        }
    }

    private func idToMessage(messageId: Int) -> Message {
        let message = MRMessage(id: messageId)
        let contact = MRContact(id: message.fromContactId)
        let messageId = "\(messageId)"
        let date = Date(timeIntervalSince1970: Double(message.timestamp))
        let sender = Sender(id: "\(contact.id)", displayName: contact.name)

        if message.isInfo {
            let text = NSAttributedString(string: message.text ?? "", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 12), NSAttributedString.Key.foregroundColor: UIColor.darkGray])
            return Message(attributedText: text, sender: sender, messageId: messageId, date: date)
        } else if let image = message.image {
            return Message(image: image, sender: sender, messageId: messageId, date: date)
        } else {
            return Message(text: message.text ?? "- empty -", sender: sender, messageId: messageId, date: date)
        }
    }

    private func messageToMRMessage(message: Message) -> MRMessage? {
        if let id = Int(message.messageId) {
            return MRMessage(id: id)
        }

        return nil
    }

    var textDraft: String? {
        // FIXME: need to free pointer
        if let draft = dc_get_draft(mailboxPointer, UInt32(chatId)) {
            if let text = dc_msg_get_text(draft) {
                let s = String(validatingUTF8: text)!
                return s
            }
            return nil
        }
        return nil
    }

    func getMessageIds() {
        let c_messageIds = dc_get_chat_msgs(mailboxPointer, UInt32(chatId), 0, 0)
        messageIds = Utils.copyAndFreeArray(inputArray: c_messageIds)

        let ids: UnsafePointer = UnsafePointer(messageIds.map { id in
            UInt32(id)
        })

        dc_markseen_msgs(mailboxPointer, ids, Int32(messageIds.count))
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let nc = NotificationCenter.default
        msgChangedObserver = nc.addObserver(forName: dc_notificationChanged,
                                            object: nil, queue: OperationQueue.main) {
            notification in
            if let ui = notification.userInfo {
                if self.chatId == ui["chat_id"] as! Int {
                    self.updateMessage(ui["message_id"] as! Int)
                }
            }
        }

        incomingMsgObserver = nc.addObserver(forName: dc_notificationIncoming,
                                             object: nil, queue: OperationQueue.main) {
            notification in
            if let ui = notification.userInfo {
                if self.chatId == ui["chat_id"] as! Int {
                    let id = ui["message_id"] as! Int
                    self.insertMessage(self.idToMessage(messageId: id))
                }
            }
        }
    }

    func setTextDraft() {
        if let text = self.messageInputBar.inputTextView.text {
            let draft = dc_msg_new(mailboxPointer, DC_MSG_TEXT)
            dc_msg_set_text(draft, text.cString(using: .utf8))
            dc_set_draft(mailboxPointer, UInt32(chatId), draft)

            // cleanup
            dc_msg_unref(draft)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        setTextDraft()
        let nc = NotificationCenter.default
        if let msgChangedObserver = self.msgChangedObserver {
            nc.removeObserver(msgChangedObserver)
        }
        if let incomingMsgObserver = self.incomingMsgObserver {
            nc.removeObserver(incomingMsgObserver)
        }
    }

    override var inputAccessoryView: UIView? {
        if disableWriting {
            return nil
        }

        return messageInputBar
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let chat = MRChat(id: chatId)
        updateTitleView(title: chat.name, subtitle: nil)

        configureMessageCollectionView()
        if !disableWriting {
            configureMessageInputBar()
            messageInputBar.inputTextView.text = textDraft
            messageInputBar.inputTextView.becomeFirstResponder()
        }

        loadFirstMessages()
    }

    func configureMessageCollectionView() {
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messageCellDelegate = self

        scrollsToBottomOnKeyboardBeginsEditing = true // default false
        maintainPositionOnKeyboardFrameChanged = true // default false

        messagesCollectionView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(loadMoreMessages), for: .valueChanged)

        let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout
        layout?.sectionInset = UIEdgeInsets(top: 1, left: 8, bottom: 1, right: 8)

        // Hide the outgoing avatar and adjust the label alignment to line up with the messages
        layout?.setMessageOutgoingAvatarSize(.zero)
        layout?.setMessageOutgoingMessageTopLabelAlignment(LabelAlignment(textAlignment: .right, textInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)))
        layout?.setMessageOutgoingMessageBottomLabelAlignment(LabelAlignment(textAlignment: .right, textInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)))

        // Set outgoing avatar to overlap with the message bubble
        layout?.setMessageIncomingMessageTopLabelAlignment(LabelAlignment(textAlignment: .left, textInsets: UIEdgeInsets(top: 0, left: 18, bottom: outgoingAvatarOverlap, right: 0)))
        layout?.setMessageIncomingAvatarSize(CGSize(width: 30, height: 30))
        layout?.setMessageIncomingMessagePadding(UIEdgeInsets(top: -outgoingAvatarOverlap, left: -18, bottom: outgoingAvatarOverlap, right: 18))

        layout?.setMessageIncomingAccessoryViewSize(CGSize(width: 30, height: 30))
        layout?.setMessageIncomingAccessoryViewPadding(HorizontalEdgeInsets(left: 8, right: 0))
        layout?.setMessageOutgoingAccessoryViewSize(CGSize(width: 30, height: 30))
        layout?.setMessageOutgoingAccessoryViewPadding(HorizontalEdgeInsets(left: 0, right: 8))

        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
    }

    func configureMessageInputBar() {
        messageInputBar.delegate = self
        messageInputBar.inputTextView.tintColor = Constants.primaryColor
        messageInputBar.sendButton.tintColor = Constants.primaryColor

        messageInputBar.isTranslucent = true
        messageInputBar.separatorLine.isHidden = true
        messageInputBar.inputTextView.tintColor = Constants.primaryColor

        messageInputBar.delegate = self
        scrollsToBottomOnKeyboardBeginsEditing = true

        messageInputBar.inputTextView.backgroundColor = UIColor(red: 245 / 255, green: 245 / 255, blue: 245 / 255, alpha: 1)
        messageInputBar.inputTextView.placeholderTextColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 38)
        messageInputBar.inputTextView.placeholderLabelInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 38)
        messageInputBar.inputTextView.layer.borderColor = UIColor(red: 200 / 255, green: 200 / 255, blue: 200 / 255, alpha: 1).cgColor
        messageInputBar.inputTextView.layer.borderWidth = 1.0
        messageInputBar.inputTextView.layer.cornerRadius = 16.0
        messageInputBar.inputTextView.layer.masksToBounds = true
        messageInputBar.inputTextView.scrollIndicatorInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        configureInputBarItems()
    }

    private func configureInputBarItems() {
        messageInputBar.setLeftStackViewWidthConstant(to: 44, animated: false)
        messageInputBar.setRightStackViewWidthConstant(to: 36, animated: false)

        let sendButtonImage = UIImage(named: "paper_plane")?.withRenderingMode(.alwaysTemplate)
        messageInputBar.sendButton.image = sendButtonImage
        messageInputBar.sendButton.tintColor = UIColor(white: 1, alpha: 1)
        messageInputBar.sendButton.backgroundColor = UIColor(white: 0.9, alpha: 1)
        messageInputBar.sendButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        messageInputBar.sendButton.setSize(CGSize(width: 34, height: 34), animated: false)

        messageInputBar.sendButton.title = nil
        messageInputBar.sendButton.layer.cornerRadius = 18

        messageInputBar.textViewPadding.right = -40

        let leftItems = [
            InputBarButtonItem()
                .configure {
                    $0.spacing = .fixed(0)
                    $0.image = UIImage(named: "camera")?.withRenderingMode(.alwaysTemplate)
                    $0.setSize(CGSize(width: 36, height: 36), animated: false)
                    $0.tintColor = UIColor(white: 0.8, alpha: 1)
                }.onSelected {
                    $0.tintColor = Constants.primaryColor
                }.onDeselected {
                    $0.tintColor = UIColor(white: 0.8, alpha: 1)
                }.onTouchUpInside { _ in
                    self.didPressPhotoButton()
                },
        ]
        messageInputBar.setStackViewItems(leftItems, forStack: .left, animated: false)

        // This just adds some more flare
        messageInputBar.sendButton
            .onEnabled { item in
                UIView.animate(withDuration: 0.3, animations: {
                    item.backgroundColor = Constants.primaryColor
                })
            }.onDisabled { item in
                UIView.animate(withDuration: 0.3, animations: {
                    item.backgroundColor = UIColor(white: 0.9, alpha: 1)
                })
            }
    }

    // MARK: - UICollectionViewDataSource

    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let messagesDataSource = messagesCollectionView.messagesDataSource else {
            fatalError("Ouch. nil data source for messages")
        }

        //        guard !isSectionReservedForTypingBubble(indexPath.section) else {
        //            return super.collectionView(collectionView, cellForItemAt: indexPath)
        //        }

        let message = messagesDataSource.messageForItem(at: indexPath, in: messagesCollectionView)
        if case .custom = message.kind {
            let cell = messagesCollectionView.dequeueReusableCell(CustomCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: messagesCollectionView)
            return cell
        }
        return super.collectionView(collectionView, cellForItemAt: indexPath)
    }
}

// MARK: - MessagesDataSource

extension ChatViewController: MessagesDataSource {
    func numberOfSections(in _: MessagesCollectionView) -> Int {
        return messageList.count
    }

    func currentSender() -> Sender {
        let currentSender = Sender(id: "1", displayName: "Alice")
        return currentSender
    }

    func messageForItem(at indexPath: IndexPath, in _: MessagesCollectionView) -> MessageType {
        return messageList[indexPath.section]
    }

    func avatar(for message: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) -> Avatar {
        if let id = Int(messageList[indexPath.section].messageId) {
            let message = MRMessage(id: id)
            let contact = message.fromContact
            return Avatar(image: contact.profileImage, initials: Utils.getInitials(inputName: contact.name))
        }

        return Avatar(image: nil, initials: "?")
    }

    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        if isTimeLabelVisible(at: indexPath) {
            return NSAttributedString(string: MessageKitDateFormatter.shared.string(from: message.sentDate), attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 10), NSAttributedString.Key.foregroundColor: UIColor.darkGray])
        }

        return nil
    }

    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        if !isPreviousMessageSameSender(at: indexPath) {
            let name = message.sender.displayName
            return NSAttributedString(string: name, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
        }
        return nil
    }

    func isTimeLabelVisible(at indexPath: IndexPath) -> Bool {
        // TODO: better heuristic when to show the time label
        return indexPath.section % 3 == 0 && !isPreviousMessageSameSender(at: indexPath)
    }

    func isPreviousMessageSameSender(at indexPath: IndexPath) -> Bool {
        guard indexPath.section - 1 >= 0 else { return false }
        return messageList[indexPath.section].sender == messageList[indexPath.section - 1].sender
    }

    func isInfoMessage(at indexPath: IndexPath) -> Bool {
        if let id = Int(messageList[indexPath.section].messageId) {
            return MRMessage(id: id).isInfo
        }

        return false
    }

    func isNextMessageSameSender(at indexPath: IndexPath) -> Bool {
        guard indexPath.section + 1 < messageList.count else { return false }
        return messageList[indexPath.section].sender == messageList[indexPath.section + 1].sender
    }

    func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        guard indexPath.section < messageList.count else { return nil }
        if let m = messageToMRMessage(message: messageList[indexPath.section]) {
            if !isNextMessageSameSender(at: indexPath), isFromCurrentSender(message: message) {
                return NSAttributedString(string: m.stateOutDescription(), attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
            }
        }
        return nil
    }

    func updateMessage(_ messageId: Int) {
        let messageIdStr = String(messageId)
        if let index = messageList.firstIndex(where: { $0.messageId == messageIdStr }) {
            messageList[index] = idToMessage(messageId: messageId)
            // Reload section to update header/footer labels
            messagesCollectionView.performBatchUpdates({
                messagesCollectionView.reloadSections([index])
                if index > 0 {
                    messagesCollectionView.reloadSections([index - 1])
                }
                if index < messageList.count - 1 {
                    messagesCollectionView.reloadSections([index + 1])
                }
            }, completion: { [weak self] _ in
                if self?.isLastSectionVisible() == true {
                    self?.messagesCollectionView.scrollToBottom(animated: true)
                }
            })
        } else {
            insertMessage(idToMessage(messageId: messageId))
        }
    }

    func insertMessage(_ message: Message) {
        messageList.append(message)
        // Reload last section to update header/footer labels and insert a new one
        messagesCollectionView.performBatchUpdates({
            messagesCollectionView.insertSections([messageList.count - 1])
            if messageList.count >= 2 {
                messagesCollectionView.reloadSections([messageList.count - 2])
            }
        }, completion: { [weak self] _ in
            if self?.isLastSectionVisible() == true {
                self?.messagesCollectionView.scrollToBottom(animated: true)
            }
        })
    }

    func isLastSectionVisible() -> Bool {
        guard !messageList.isEmpty else { return false }

        let lastIndexPath = IndexPath(item: 0, section: messageList.count - 1)
        return messagesCollectionView.indexPathsForVisibleItems.contains(lastIndexPath)
    }
}

// MARK: - MessagesDisplayDelegate

extension ChatViewController: MessagesDisplayDelegate {
    // MARK: - Text Messages

    func textColor(for _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> UIColor {
        return .darkText
    }

    // MARK: - All Messages

    func backgroundColor(for message: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? Constants.messagePrimaryColor : Constants.messageSecondaryColor
    }

    func messageStyle(for message: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) -> MessageStyle {
        if isInfoMessage(at: indexPath) {
            return .custom { view in
                view.style = .none
                view.backgroundColor = UIColor(alpha: 0, red: 0, green: 0, blue: 0)
                view.center.x = self.view.center.x
            }
        }

        var corners: UIRectCorner = []

        if isFromCurrentSender(message: message) {
            corners.formUnion(.topLeft)
            corners.formUnion(.bottomLeft)
            if !isPreviousMessageSameSender(at: indexPath) {
                corners.formUnion(.topRight)
            }
            if !isNextMessageSameSender(at: indexPath) {
                corners.formUnion(.bottomRight)
            }
        } else {
            corners.formUnion(.topRight)
            corners.formUnion(.bottomRight)
            if !isPreviousMessageSameSender(at: indexPath) {
                corners.formUnion(.topLeft)
            }
            if !isNextMessageSameSender(at: indexPath) {
                corners.formUnion(.bottomLeft)
            }
        }

        return .custom { view in
            let radius: CGFloat = 16
            let path = UIBezierPath(roundedRect: view.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
            let mask = CAShapeLayer()
            mask.path = path.cgPath
            view.layer.mask = mask
        }
    }

    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) {
        if let id = Int(messageList[indexPath.section].messageId) {
            let message = MRMessage(id: id)
            let contact = message.fromContact
            let avatar = Avatar(image: contact.profileImage, initials: Utils.getInitials(inputName: contact.name))
            avatarView.set(avatar: avatar)
            avatarView.isHidden = isNextMessageSameSender(at: indexPath) || message.isInfo
        }
    }

    func enabledDetectors(for _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> [DetectorType] {
        return [.url, .date, .phoneNumber, .address]
    }
}

// MARK: - MessagesLayoutDelegate

extension ChatViewController: MessagesLayoutDelegate {
    func cellTopLabelHeight(for _: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) -> CGFloat {
        if isTimeLabelVisible(at: indexPath) {
            return 18
        }
        return 0
    }

    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) -> CGFloat {
        if isFromCurrentSender(message: message) {
            return !isPreviousMessageSameSender(at: indexPath) ? 20 : 0
        } else {
            return !isPreviousMessageSameSender(at: indexPath) ? (20 + outgoingAvatarOverlap) : 0
        }
    }

    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) -> CGFloat {
        return (!isNextMessageSameSender(at: indexPath) && isFromCurrentSender(message: message)) && !isInfoMessage(at: indexPath) ? 16 : 0
    }

    func heightForLocation(message _: MessageType, at _: IndexPath, with _: CGFloat, in _: MessagesCollectionView) -> CGFloat {
        return 40
    }

    func footerViewSize(for _: MessageType, at _: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize {
        return CGSize(width: messagesCollectionView.bounds.width, height: 10)
    }

    @objc func didPressPhotoButton() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.sourceType = .camera
            imagePicker.cameraDevice = .rear
            imagePicker.delegate = self
            imagePicker.allowsEditing = true
            present(imagePicker, animated: true, completion: nil)
        } else {
            logger.info("no camera available")
        }
    }

    fileprivate func saveImage(image: UIImage) -> String? {
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL else {
            return nil
        }

        let size = image.size.applying(CGAffineTransform(scaleX: 0.2, y: 0.2))
        let hasAlpha = false
        let scale: CGFloat = 0.0

        UIGraphicsBeginImageContextWithOptions(size, !hasAlpha, scale)
        image.draw(in: CGRect(origin: CGPoint.zero, size: size))

        let _scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let scaledImage = _scaledImage else {
            return nil
        }

        guard let data = scaledImage.jpegData(compressionQuality: 0.9) else {
            return nil
        }

        do {
            let timestamp = Int(Date().timeIntervalSince1970)
            let path = directory.appendingPathComponent("\(chatId)_\(timestamp).jpg")
            try data.write(to: path!)
            return path?.relativePath
        } catch {
            logger.info(error.localizedDescription)
            return nil
        }
    }
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        DispatchQueue.global().async {
            if let pickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage,
                let width = Int32(exactly: pickedImage.size.width),
                let height = Int32(exactly: pickedImage.size.height),
                let path = self.saveImage(image: pickedImage) {
                let msg = dc_msg_new(mailboxPointer, DC_MSG_IMAGE)
                dc_msg_set_file(msg, path, "image/jpeg")
                dc_msg_set_dimension(msg, width, height)
                dc_send_msg(mailboxPointer, UInt32(self.chatId), msg)

                // cleanup
                dc_msg_unref(msg)
            }
        }

        dismiss(animated: true, completion: nil)
    }
}

// MARK: - MessageCellDelegate

extension ChatViewController: MessageCellDelegate {
    func didTapMessage(in _: MessageCollectionViewCell) {
        logger.info("Message tapped")
    }

    func didTapAvatar(in _: MessageCollectionViewCell) {
        logger.info("Avatar tapped")
    }

    @objc(didTapCellTopLabelIn:) func didTapCellTopLabel(in _: MessageCollectionViewCell) {
        logger.info("Top label tapped")
    }

    func didTapBottomLabel(in _: MessageCollectionViewCell) {
        print("Bottom label tapped")
    }
}

// MARK: - MessageLabelDelegate

extension ChatViewController: MessageLabelDelegate {
    func didSelectAddress(_ addressComponents: [String: String]) {
        let mapAddress = Utils.formatAddressForQuery(address: addressComponents)
        if let escapedMapAddress = mapAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            // Use query, to handle malformed addresses
            if let url = URL(string: "http://maps.apple.com/?q=\(escapedMapAddress)") {
                UIApplication.shared.open(url as URL)
            }
        }
    }

    func didSelectDate(_ date: Date) {
        let interval = date.timeIntervalSinceReferenceDate
        if let url = NSURL(string: "calshow:\(interval)") {
            UIApplication.shared.open(url as URL)
        }
    }

    func didSelectPhoneNumber(_ phoneNumber: String) {
        logger.info("phone open", phoneNumber)
        if let escapedPhoneNumber = phoneNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            if let url = NSURL(string: "tel:\(escapedPhoneNumber)") {
                UIApplication.shared.open(url as URL)
            }
        }
    }

    func didSelectURL(_ url: URL) {
        UIApplication.shared.open(url)
    }
}

// MARK: - LocationMessageDisplayDelegate

/*
 extension ChatViewController: LocationMessageDisplayDelegate {
 func annotationViewForLocation(message: MessageType, at indexPath: IndexPath, in messageCollectionView: MessagesCollectionView) -> MKAnnotationView? {
 let annotationView = MKAnnotationView(annotation: nil, reuseIdentifier: nil)
 let pinImage = #imageLiteral(resourceName: "ic_block_36pt").withRenderingMode(.alwaysTemplate)
 annotationView.image = pinImage
 annotationView.centerOffset = CGPoint(x: 0, y: -pinImage.size.height / 2)
 return annotationView
 }

 func animationBlockForLocation(message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> ((UIImageView) -> Void)? {
 return { view in
 view.layer.transform = CATransform3DMakeScale(0, 0, 0)
 view.alpha = 0.0
 UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: [], animations: {
 view.layer.transform = CATransform3DIdentity
 view.alpha = 1.0
 }, completion: nil)
 }
 }
 }
 */

// MARK: - MessageInputBarDelegate

extension ChatViewController: MessageInputBarDelegate {
    func messageInputBar(_ inputBar: MessageInputBar, didPressSendButtonWith text: String) {
        DispatchQueue.global().async {
            dc_send_text_msg(mailboxPointer, UInt32(self.chatId), text)
        }
        inputBar.inputTextView.text = String()
    }
}

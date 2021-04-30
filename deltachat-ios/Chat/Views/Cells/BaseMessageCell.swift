import UIKit
import DcCore

public class BaseMessageCell: UITableViewCell {

    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var leadingConstraintCurrentSender: NSLayoutConstraint?
    private var leadingConstraintGroup: NSLayoutConstraint?
    private var trailingConstraintCurrentSender: NSLayoutConstraint?
    private var mainContentBelowTopLabelConstraint: NSLayoutConstraint?
    private var mainContentUnderTopLabelConstraint: NSLayoutConstraint?
    private var mainContentAboveFullMessageBtnConstraint: NSLayoutConstraint?
    private var mainContentUnderBottomLabelConstraint: NSLayoutConstraint?
    private var mainContentViewLeadingConstraint: NSLayoutConstraint?
    private var mainContentViewTrailingConstraint: NSLayoutConstraint?
    private var fullMessageZeroHeightConstraint: NSLayoutConstraint?

    public var mainContentViewHorizontalPadding: CGFloat {
        set {
            mainContentViewLeadingConstraint?.constant = newValue
            mainContentViewTrailingConstraint?.constant = -newValue
        }
        get {
            return mainContentViewLeadingConstraint?.constant ?? 0
        }
    }

    // if set to true topLabel overlaps the main content
    public var topCompactView: Bool {
        set {
            mainContentBelowTopLabelConstraint?.isActive = !newValue
            mainContentUnderTopLabelConstraint?.isActive = newValue
            topLabel.backgroundColor = newValue ?
                UIColor(alpha: 200, red: 20, green: 20, blue: 20) :
                UIColor(alpha: 0, red: 0, green: 0, blue: 0)
        }
        get {
            return mainContentUnderTopLabelConstraint?.isActive ?? false
        }
    }

    // if set to true bottomLabel overlaps the main content
    public var bottomCompactView: Bool {
        set {
            mainContentAboveFullMessageBtnConstraint?.isActive = !newValue
            mainContentUnderBottomLabelConstraint?.isActive = newValue
            bottomLabel.backgroundColor = newValue ?
                UIColor(alpha: 200, red: 50, green: 50, blue: 50) :
                UIColor(alpha: 0, red: 0, green: 0, blue: 0)
        }
        get {
            return mainContentUnderBottomLabelConstraint?.isActive ?? false
        }
    }

    public var isFullMessageButtonHidden: Bool {
        set {
            mainContentAboveFullMessageBtnConstraint?.constant = newValue ? -2 : 8
            fullMessageButton.setTitle(newValue ? "" : String.localized("show_full_message"), for: .normal)
            fullMessageZeroHeightConstraint?.isActive = newValue
            fullMessageButton.isHidden = newValue
        }
        get {
            return fullMessageButton.isHidden
        }
    }

    public weak var baseDelegate: BaseMessageCellDelegate?

    public lazy var quoteView: QuoteView = {
        let view = QuoteView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        view.isHidden = true
        view.isAccessibilityElement = false
        return view
    }()

    public lazy var messageLabel: PaddingTextView = {
        let view = PaddingTextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.font = UIFont.preferredFont(for: .body, weight: .regular)
        view.delegate = self
        view.enabledDetectors = [.url, .phoneNumber]
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor,
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
            NSAttributedString.Key.underlineColor: DcColors.defaultTextColor ]
        view.label.setAttributes(attributes, detector: .url)
        view.label.setAttributes(attributes, detector: .phoneNumber)
        view.isUserInteractionEnabled = true
        view.isAccessibilityElement = false
        return view
    }()

    lazy var avatarView: InitialsBadge = {
        let view = InitialsBadge(size: 28)
        view.setColor(UIColor.gray)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        view.isHidden = true
        view.isUserInteractionEnabled = true
        return view
    }()

    lazy var topLabel: PaddingTextView = {
        let view = PaddingTextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = UIFont.preferredFont(for: .caption1, weight: .bold)
        view.layer.cornerRadius = 4
        view.numberOfLines = 1
        view.label.lineBreakMode = .byTruncatingTail
        view.clipsToBounds = true
        view.paddingLeading = 4
        view.paddingTrailing = 4
        view.isAccessibilityElement = false
        return view
    }()

    lazy var mainContentView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [quoteView])
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        return view
    }()

    lazy var fullMessageButton: DynamicFontButton = {
        let button = DynamicFontButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(.systemBlue, for: .normal)
        button.setTitleColor(.gray, for: .highlighted)
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.titleLabel?.textAlignment = .left
        button.addTarget(self, action: #selector(onFullMessageButtonTapped), for: .touchUpInside)
        button.titleLabel?.font = UIFont.preferredFont(for: .body, weight: .regular)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        button.accessibilityLabel = String.localized("show_full_message")
        return button
    }()

    lazy var bottomLabel: PaddingTextView = {
        let label = PaddingTextView()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(for: .caption1, weight: .regular)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        label.layer.cornerRadius = 4
        label.paddingLeading = 4
        label.paddingTrailing = 4
        label.clipsToBounds = true
        label.isAccessibilityElement = false
        return label
    }()

    private lazy var messageBackgroundContainer: BackgroundContainer = {
        let container = BackgroundContainer()
        container.image = UIImage(color: UIColor.blue)
        container.contentMode = .scaleToFill
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isUserInteractionEnabled = true
        return container
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        clipsToBounds = false
        backgroundColor = .none
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    func setupSubviews() {
        selectedBackgroundView = UIView()
        contentView.addSubview(messageBackgroundContainer)
        messageBackgroundContainer.addSubview(mainContentView)
        messageBackgroundContainer.addSubview(topLabel)
        messageBackgroundContainer.addSubview(fullMessageButton)
        messageBackgroundContainer.addSubview(bottomLabel)
        contentView.addSubview(avatarView)

        contentView.addConstraints([
            avatarView.constraintAlignLeadingTo(contentView, paddingLeading: 2),
            avatarView.constraintAlignBottomTo(contentView),
            avatarView.constraintWidthTo(28, priority: .defaultHigh),
            avatarView.constraintHeightTo(28, priority: .defaultHigh),
            topLabel.constraintAlignTopTo(messageBackgroundContainer, paddingTop: 6),
            topLabel.constraintAlignLeadingTo(messageBackgroundContainer, paddingLeading: 8),
            topLabel.constraintAlignTrailingMaxTo(messageBackgroundContainer, paddingTrailing: 8),
            messageBackgroundContainer.constraintAlignTopTo(contentView, paddingTop: 3),
            messageBackgroundContainer.constraintAlignBottomTo(contentView, paddingBottom: 3),
            fullMessageButton.constraintAlignLeadingTo(messageBackgroundContainer, paddingLeading: 12),
            fullMessageButton.constraintAlignTrailingMaxTo(messageBackgroundContainer, paddingTrailing: 12),
            bottomLabel.constraintAlignLeadingMaxTo(messageBackgroundContainer, paddingLeading: 8),
            bottomLabel.constraintAlignTrailingTo(messageBackgroundContainer, paddingTrailing: 8),
            bottomLabel.constraintToBottomOf(fullMessageButton, paddingTop: 8, priority: .defaultHigh),
            bottomLabel.constraintAlignBottomTo(messageBackgroundContainer, paddingBottom: 6)
        ])

        leadingConstraint = messageBackgroundContainer.constraintAlignLeadingTo(contentView, paddingLeading: 6)
        leadingConstraintGroup = messageBackgroundContainer.constraintToTrailingOf(avatarView, paddingLeading: 2)
        trailingConstraint = messageBackgroundContainer.constraintAlignTrailingMaxTo(contentView, paddingTrailing: 36)
        leadingConstraintCurrentSender = messageBackgroundContainer.constraintAlignLeadingMaxTo(contentView, paddingLeading: 36)
        trailingConstraintCurrentSender = messageBackgroundContainer.constraintAlignTrailingTo(contentView, paddingTrailing: 6)

        mainContentViewLeadingConstraint = mainContentView.constraintAlignLeadingTo(messageBackgroundContainer)
        mainContentViewTrailingConstraint = mainContentView.constraintAlignTrailingTo(messageBackgroundContainer)
        mainContentViewLeadingConstraint?.isActive = true
        mainContentViewTrailingConstraint?.isActive = true

        mainContentBelowTopLabelConstraint = mainContentView.constraintToBottomOf(topLabel, paddingTop: 6)
        mainContentUnderTopLabelConstraint = mainContentView.constraintAlignTopTo(messageBackgroundContainer)
        mainContentAboveFullMessageBtnConstraint = fullMessageButton.constraintToBottomOf(mainContentView, paddingTop: 8, priority: .defaultHigh)
        mainContentUnderBottomLabelConstraint = mainContentView.constraintAlignBottomTo(messageBackgroundContainer, paddingBottom: 0, priority: .defaultHigh)

        fullMessageZeroHeightConstraint = fullMessageButton.constraintHeightTo(0)

        topCompactView = false
        bottomCompactView = false
        isFullMessageButtonHidden = true
        

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onAvatarTapped))
        gestureRecognizer.numberOfTapsRequired = 1
        avatarView.addGestureRecognizer(gestureRecognizer)

        let messageLabelGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        messageLabelGestureRecognizer.numberOfTapsRequired = 1
        messageLabel.addGestureRecognizer(messageLabelGestureRecognizer)

        let quoteViewGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onQuoteTapped))
        quoteViewGestureRecognizer.numberOfTapsRequired = 1
        quoteView.addGestureRecognizer(quoteViewGestureRecognizer)

    }

    @objc
    open func handleTapGesture(_ gesture: UIGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let touchLocation = gesture.location(in: messageLabel)
        let isHandled = messageLabel.label.handleGesture(touchLocation)
        if !isHandled, let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            self.baseDelegate?.textTapped(indexPath: indexPath)
        }
    }

    @objc func onAvatarTapped() {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            baseDelegate?.avatarTapped(indexPath: indexPath)
        }
    }

    @objc func onQuoteTapped() {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            baseDelegate?.quoteTapped(indexPath: indexPath)
        }
    }

    @objc func onFullMessageButtonTapped() {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            baseDelegate?.fullMessageTapped(indexPath: indexPath)
        }
    }

    // update classes inheriting BaseMessageCell first before calling super.update(...)
    func update(msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool) {
        if msg.isFromCurrentSender {
            topLabel.text = msg.isForwarded ? String.localized("forwarded_message") : nil
            topLabel.textColor = msg.isForwarded ? DcColors.grayDateColor : DcColors.defaultTextColor
            leadingConstraint?.isActive = false
            leadingConstraintGroup?.isActive = false
            trailingConstraint?.isActive = false
            leadingConstraintCurrentSender?.isActive = true
            trailingConstraintCurrentSender?.isActive = true

        } else {
            topLabel.text = msg.isForwarded ? String.localized("forwarded_message") :
                showName ? msg.getSenderName(msg.fromContact, markOverride: true) : nil
            topLabel.textColor = msg.isForwarded ? DcColors.grayDateColor :
                showName ? msg.fromContact.color : DcColors.defaultTextColor
            leadingConstraintCurrentSender?.isActive = false
            trailingConstraintCurrentSender?.isActive = false
            if showName {
                leadingConstraint?.isActive = false
                leadingConstraintGroup?.isActive = true
            } else {
                leadingConstraintGroup?.isActive = false
                leadingConstraint?.isActive = true
            }
            trailingConstraint?.isActive = true
        }

        if showAvatar {
            avatarView.isHidden = false
            avatarView.setName(msg.getSenderName(msg.fromContact))
            avatarView.setColor(msg.fromContact.color)
            if let profileImage = msg.fromContact.profileImage {
                avatarView.setImage(profileImage)
            }
        } else {
            avatarView.isHidden = true
        }

        isFullMessageButtonHidden = !msg.hasHtml

        messageBackgroundContainer.update(rectCorners: messageStyle,
                                          color: msg.isFromCurrentSender ? DcColors.messagePrimaryColor : DcColors.messageSecondaryColor)

        if !msg.isInfo {
            bottomLabel.attributedText = getFormattedBottomLine(message: msg)
        }

        if let quoteText = msg.quoteText {
            quoteView.isHidden = false
            quoteView.quote.text = quoteText

            if let quoteMsg = msg.quoteMessage {
                quoteView.setImagePreview(quoteMsg.image)
                if quoteMsg.isForwarded {
                    quoteView.senderTitle.text = String.localized("forwarded_message")
                    quoteView.senderTitle.textColor = DcColors.grayDateColor
                    quoteView.citeBar.backgroundColor = DcColors.grayDateColor
                } else {
                    let contact = quoteMsg.fromContact
                    quoteView.senderTitle.text = quoteMsg.getSenderName(contact, markOverride: true)
                    quoteView.senderTitle.textColor = contact.color
                    quoteView.citeBar.backgroundColor = contact.color
                }

            }
        } else {
            quoteView.isHidden = true
        }

        messageLabel.delegate = self
        accessibilityLabel = configureAccessibilityString(message: msg)
    }

    func configureAccessibilityString(message: DcMsg) -> String {
        var topLabelAccessibilityString = ""
        var quoteAccessibilityString = ""
        var messageLabelAccessibilityString = ""
        var additionalAccessibilityString = ""

        if let topLabelText = topLabel.text {
            topLabelAccessibilityString = "\(topLabelText), "
        }
        if let messageLabelText = messageLabel.text {
            messageLabelAccessibilityString = "\(messageLabelText), "
        }
        if let senderTitle = quoteView.senderTitle.text, let quote = quoteView.quote.text {
            quoteAccessibilityString = "\(senderTitle), \(quote), \(String.localized("reply_noun")), "
        }
        if let additionalAccessibilityInfo = accessibilityLabel {
            additionalAccessibilityString = "\(additionalAccessibilityInfo), "
        }

        return "\(topLabelAccessibilityString) " +
            "\(quoteAccessibilityString) " +
            "\(additionalAccessibilityString) " +
            "\(messageLabelAccessibilityString) " +
            "\(getFormattedBottomLineAccessibilityString(message: message))"
    }

    func getFormattedBottomLineAccessibilityString(message: DcMsg) -> String {
        let padlock =  message.showPadlock() ? "\(String.localized("encrypted_message")), " : ""
        let date = "\(message.formattedSentDate()), "
        let sendingState = "\(getSendingStateString(message.state))"
        return "\(date) \(padlock) \(sendingState)"
    }

    func getFormattedBottomLine(message: DcMsg) -> NSAttributedString {

        var paragraphStyle = NSParagraphStyle()
        if let style = NSMutableParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle {
            paragraphStyle = style
        }

        var timestampAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(for: .caption1, weight: .regular),
            .foregroundColor: DcColors.grayDateColor,
            .paragraphStyle: paragraphStyle,
        ]

        let text = NSMutableAttributedString()
        if message.fromContactId == Int(DC_CONTACT_ID_SELF) {
            if let style = NSMutableParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle {
                style.alignment = .right
                timestampAttributes[.paragraphStyle] = style
                if !bottomCompactView {
                    timestampAttributes[.foregroundColor] = DcColors.checkmarkGreen
                }
            }

            text.append(NSAttributedString(string: message.formattedSentDate(), attributes: timestampAttributes))
            if message.showPadlock() {
                attachPadlock(to: text, color: bottomCompactView ? nil : DcColors.checkmarkGreen)
            }

            attachSendingState(message.state, to: text)
            return text
        }

        text.append(NSAttributedString(string: message.formattedSentDate(), attributes: timestampAttributes))
        if message.showPadlock() {
            attachPadlock(to: text)
        }
        return text
    }

    private func attachPadlock(to text: NSMutableAttributedString, color: UIColor? = nil) {
        let imageAttachment = NSTextAttachment()
        if let color = color {
            imageAttachment.image = UIImage(named: "ic_lock")?.maskWithColor(color: color)?.scaleDownImage(toMax: 15)
        } else {
            imageAttachment.image = UIImage(named: "ic_lock")?.scaleDownImage(toMax: 15)
        }
        let imageString = NSMutableAttributedString(attachment: imageAttachment)
        imageString.addAttributes([NSAttributedString.Key.baselineOffset: -0.5], range: NSRange(location: 0, length: 1))
        text.append(NSAttributedString(string: " "))
        text.append(imageString)
    }

    private func getSendingStateString(_ state: Int) -> String {
        switch Int32(state) {
        case DC_STATE_OUT_PENDING, DC_STATE_OUT_PREPARING:
            return String.localized("a11y_delivery_status_sending")
        case DC_STATE_OUT_DELIVERED:
            return String.localized("a11y_delivery_status_delivered")
        case DC_STATE_OUT_MDN_RCVD:
            return String.localized("a11y_delivery_status_read")
        case DC_STATE_OUT_FAILED:
            return String.localized("a11y_delivery_status_error")
        default:
            return ""
        }
    }

    private func attachSendingState(_ state: Int, to text: NSMutableAttributedString) {
        let imageAttachment = NSTextAttachment()
        var offset: CGFloat = -2

        switch Int32(state) {
        case DC_STATE_OUT_PENDING, DC_STATE_OUT_PREPARING:
            imageAttachment.image = #imageLiteral(resourceName: "ic_hourglass_empty_white_36pt").scaleDownImage(toMax: 14)?.maskWithColor(color: DcColors.grayDateColor)
        case DC_STATE_OUT_DELIVERED:
            imageAttachment.image = #imageLiteral(resourceName: "ic_done_36pt").scaleDownImage(toMax: 16)?.sd_croppedImage(with: CGRect(x: 0, y: 4, width: 16, height: 14))
            offset = -3.5
        case DC_STATE_OUT_MDN_RCVD:
            imageAttachment.image = #imageLiteral(resourceName: "ic_done_all_36pt").scaleDownImage(toMax: 16)?.sd_croppedImage(with: CGRect(x: 0, y: 4, width: 16, height: 14))
            text.append(NSAttributedString(string: " "))
            offset = -3.5
        case DC_STATE_OUT_FAILED:
            imageAttachment.image = #imageLiteral(resourceName: "ic_error_36pt").scaleDownImage(toMax: 14)
        default:
            imageAttachment.image = nil
        }
        let imageString = NSMutableAttributedString(attachment: imageAttachment)
        imageString.addAttributes([.baselineOffset: offset],
                                  range: NSRange(location: 0, length: 1))
        text.append(imageString)
    }

    override public func prepareForReuse() {
        accessibilityLabel = nil
        textLabel?.text = nil
        textLabel?.attributedText = nil
        topLabel.text = nil
        topLabel.attributedText = nil
        avatarView.reset()
        messageBackgroundContainer.prepareForReuse()
        bottomLabel.text = nil
        bottomLabel.attributedText = nil
        baseDelegate = nil
        messageLabel.text = nil
        messageLabel.attributedText = nil
        messageLabel.delegate = nil
        quoteView.prepareForReuse()
    }

    // MARK: - Context menu
    @objc func messageInfo(_ sender: Any?) {
        self.performAction(#selector(BaseMessageCell.messageInfo(_:)), with: sender)
    }

    @objc func messageDelete(_ sender: Any?) {
        self.performAction(#selector(BaseMessageCell.messageDelete(_:)), with: sender)
    }

    @objc func messageForward(_ sender: Any?) {
        self.performAction(#selector(BaseMessageCell.messageForward(_:)), with: sender)
    }

    @objc func messageReply(_ sender: Any?) {
        self.performAction(#selector(BaseMessageCell.messageReply(_:)), with: sender)
    }

    @objc func messageCopy(_ sender: Any?) {
        self.performAction(#selector(BaseMessageCell.messageCopy(_:)), with: sender)
    }

    @objc func messageSelectMore(_ sender: Any?) {
        self.performAction(#selector(BaseMessageCell.messageSelectMore(_:)), with: sender)
    }

    func performAction(_ action: Selector, with sender: Any?) {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            // Trigger action in tableView delegate (UITableViewController)
            tableView.delegate?.tableView?(tableView,
                                           performAction: action,
                                           forRowAt: indexPath,
                                           withSender: sender)
        }
    }
}

extension BaseMessageCell: MessageLabelDelegate {
    public func didSelectAddress(_ addressComponents: [String: String]) {}

    public func didSelectDate(_ date: Date) {}

    public func didSelectPhoneNumber(_ phoneNumber: String) {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            baseDelegate?.phoneNumberTapped(number: phoneNumber, indexPath: indexPath)
        }

    }

    public func didSelectURL(_ url: URL) {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            logger.debug("did select URL")
            baseDelegate?.urlTapped(url: url, indexPath: indexPath)
        }
    }

    public func didSelectTransitInformation(_ transitInformation: [String: String]) {}

    public func didSelectMention(_ mention: String) {}

    public func didSelectHashtag(_ hashtag: String) {}

    public func didSelectCustom(_ pattern: String, match: String?) {}
}

// MARK: - BaseMessageCellDelegate
// this delegate contains possible events from base cells or from derived cells
public protocol BaseMessageCellDelegate: class {
    func commandTapped(command: String, indexPath: IndexPath) // `/command`
    func phoneNumberTapped(number: String, indexPath: IndexPath)
    func urlTapped(url: URL, indexPath: IndexPath) // url is eg. `https://foo.bar`
    func imageTapped(indexPath: IndexPath)
    func avatarTapped(indexPath: IndexPath)
    func textTapped(indexPath: IndexPath)
    func quoteTapped(indexPath: IndexPath)
    func fullMessageTapped(indexPath: IndexPath)
}

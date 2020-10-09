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
    private var mainContentAboveBottomLabelConstraint: NSLayoutConstraint?
    private var mainContentUnderBottomLabelConstraint: NSLayoutConstraint?
    private var bottomLineLeftAlignedConstraint: [NSLayoutConstraint] = []
    private var bottomLineRightAlignedConstraint: [NSLayoutConstraint] = []
    private var mainContentViewLeadingConstraint: NSLayoutConstraint?
    private var mainContentViewTrailingConstraint: NSLayoutConstraint?

    public var mainContentViewHorizontalPadding: CGFloat {
        set {
            mainContentViewLeadingConstraint?.constant = newValue
            mainContentViewTrailingConstraint?.constant = -newValue
        }
        get {
            return mainContentViewLeadingConstraint?.constant ?? 0
        }
    }

    //aligns the bottomLabel to the left / right
    private var bottomLineLeftAlign: Bool {
        set {
            for constraint in bottomLineLeftAlignedConstraint {
                constraint.isActive = newValue
            }
            for constraint in bottomLineRightAlignedConstraint {
                constraint.isActive = !newValue
            }
        }
        get {
            return !bottomLineLeftAlignedConstraint.isEmpty && bottomLineLeftAlignedConstraint[0].isActive
        }
    }

    // if set to true topLabel overlaps the main content
    public var topCompactView: Bool {
        set {
            mainContentBelowTopLabelConstraint?.isActive = !newValue
            mainContentUnderTopLabelConstraint?.isActive = newValue
            topLabel.backgroundColor = newValue ?
                UIColor(alpha: 200, red: 50, green: 50, blue: 50) :
                UIColor(alpha: 0, red: 0, green: 0, blue: 0)
        }
        get {
            return mainContentUnderTopLabelConstraint?.isActive ?? false
        }
    }

    // if set to true bottomLabel overlaps the main content
    public var bottomCompactView: Bool {
        set {
            mainContentAboveBottomLabelConstraint?.isActive = !newValue
            mainContentUnderBottomLabelConstraint?.isActive = newValue
            bottomLabel.backgroundColor = newValue ?
                UIColor(alpha: 200, red: 50, green: 50, blue: 50) :
                UIColor(alpha: 0, red: 0, green: 0, blue: 0)
        }
        get {
            return mainContentUnderBottomLabelConstraint?.isActive ?? false
        }
    }

    public weak var baseDelegate: BaseMessageCellDelegate?

    lazy var messageLabel: PaddingTextView = {
        let view = PaddingTextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.font = UIFont.preferredFont(for: .body, weight: .regular)
        view.delegate = self
        view.enabledDetectors = [.url, .phoneNumber]
        let attributes: [NSAttributedString.Key : Any] = [
            NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor,
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
            NSAttributedString.Key.underlineColor: DcColors.defaultTextColor ]
        view.label.setAttributes(attributes, detector: .url)
        view.label.setAttributes(attributes, detector: .phoneNumber)
        view.isUserInteractionEnabled = true
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
        let view = PaddingTextView(top: 0, left: 4, bottom: 0, right: 4)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.text = "title"
        view.font = UIFont.preferredFont(for: .caption1, weight: .regular)
        view.layer.cornerRadius = 4
        view.clipsToBounds = true
        return view
    }()

    lazy var mainContentView: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        return view
    }()

    lazy var bottomLabel: PaddingTextView = {
        let label = PaddingTextView(top: 0, left: 4, bottom: 0, right: 4)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(for: .caption1, weight: .regular)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
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
        contentView.addSubview(messageBackgroundContainer)
        messageBackgroundContainer.addSubview(mainContentView)
        messageBackgroundContainer.addSubview(topLabel)
        messageBackgroundContainer.addSubview(bottomLabel)
        contentView.addSubview(avatarView)

        contentView.addConstraints([
            avatarView.constraintAlignLeadingTo(contentView, paddingLeading: 6),
            avatarView.constraintAlignBottomTo(contentView, paddingBottom: -6),
            avatarView.constraintWidthTo(28, priority: .defaultHigh),
            avatarView.constraintHeightTo(28, priority: .defaultHigh),
            topLabel.constraintAlignTopTo(messageBackgroundContainer, paddingTop: 6),
            topLabel.constraintAlignLeadingTo(messageBackgroundContainer, paddingLeading: 6),
            topLabel.constraintAlignTrailingMaxTo(messageBackgroundContainer, paddingTrailing: 6),
            bottomLabel.constraintAlignBottomTo(messageBackgroundContainer, paddingBottom: 6),
            messageBackgroundContainer.constraintAlignTopTo(contentView, paddingTop: 6),
            messageBackgroundContainer.constraintAlignBottomTo(contentView),
        ])

        leadingConstraint = messageBackgroundContainer.constraintAlignLeadingTo(contentView, paddingLeading: 6)
        leadingConstraintGroup = messageBackgroundContainer.constraintToTrailingOf(avatarView, paddingLeading: -8)
        trailingConstraint = messageBackgroundContainer.constraintAlignTrailingMaxTo(contentView, paddingTrailing: 36)
        leadingConstraintCurrentSender = messageBackgroundContainer.constraintAlignLeadingMaxTo(contentView, paddingLeading: 36)
        trailingConstraintCurrentSender = messageBackgroundContainer.constraintAlignTrailingTo(contentView, paddingTrailing: 6)

        mainContentViewLeadingConstraint = mainContentView.constraintAlignLeadingTo(messageBackgroundContainer)
        mainContentViewTrailingConstraint = mainContentView.constraintAlignTrailingTo(messageBackgroundContainer)
        mainContentViewLeadingConstraint?.isActive = true
        mainContentViewTrailingConstraint?.isActive = true

        mainContentBelowTopLabelConstraint = mainContentView.constraintToBottomOf(topLabel, paddingTop: 6)
        mainContentUnderTopLabelConstraint = mainContentView.constraintAlignTopTo(messageBackgroundContainer)
        mainContentAboveBottomLabelConstraint = bottomLabel.constraintToBottomOf(mainContentView, paddingTop: 6, priority: .defaultHigh)
        mainContentUnderBottomLabelConstraint = mainContentView.constraintAlignBottomTo(messageBackgroundContainer, paddingBottom: 0, priority: .defaultHigh)

        bottomLineRightAlignedConstraint = [bottomLabel.constraintAlignLeadingMaxTo(messageBackgroundContainer, paddingLeading: 6),
                                           bottomLabel.constraintAlignTrailingTo(messageBackgroundContainer, paddingTrailing: 6)]
        bottomLineLeftAlignedConstraint = [bottomLabel.constraintAlignLeadingTo(messageBackgroundContainer, paddingLeading: 6),
                                           bottomLabel.constraintAlignTrailingMaxTo(messageBackgroundContainer, paddingTrailing: 6)]

        topCompactView = false
        bottomCompactView = false
        selectionStyle = .none

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onAvatarTapped))
        gestureRecognizer.numberOfTapsRequired = 1
        avatarView.addGestureRecognizer(gestureRecognizer)

        let messageLabelGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        //messageLabelGestureRecognizer.delaysTouchesBegan = true
        gestureRecognizer.numberOfTapsRequired = 1
        messageLabel.addGestureRecognizer(messageLabelGestureRecognizer)
    }

    @objc
    open func handleTapGesture(_ gesture: UIGestureRecognizer) {
        guard gesture.state == .ended else { return }

        let touchLocation = gesture.location(in: messageLabel)
        let _ = messageLabel.label.handleGesture(touchLocation)
    }



    @objc func onAvatarTapped() {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            baseDelegate?.avatarTapped(indexPath: indexPath)
        }
    }

    // update classes inheriting BaseMessageCell first before calling super.update(...)
    func update(msg: DcMsg, messageStyle: UIRectCorner, isAvatarVisible: Bool, isGroup: Bool) {
        if msg.isFromCurrentSender {
            topLabel.text = nil
            leadingConstraint?.isActive = false
            leadingConstraintGroup?.isActive = false
            trailingConstraint?.isActive = false
            bottomLineLeftAlign = false
            leadingConstraintCurrentSender?.isActive = true
            trailingConstraintCurrentSender?.isActive = true

        } else {
            topLabel.text = isGroup ? msg.fromContact.displayName : nil
            leadingConstraintCurrentSender?.isActive = false
            trailingConstraintCurrentSender?.isActive = false
            if isGroup {
                leadingConstraint?.isActive = false
                leadingConstraintGroup?.isActive = true
            } else {
                leadingConstraintGroup?.isActive = false
                leadingConstraint?.isActive = true
            }
            trailingConstraint?.isActive = true
            bottomLineLeftAlign = true
        }

        if isAvatarVisible {
            avatarView.isHidden = false
            avatarView.setName(msg.fromContact.displayName)
            avatarView.setColor(msg.fromContact.color)
            if let profileImage = msg.fromContact.profileImage {
                avatarView.setImage(profileImage)
            }
        } else {
            avatarView.isHidden = true
        }

        messageBackgroundContainer.update(rectCorners: messageStyle,
                                          color: msg.isFromCurrentSender ? DcColors.messagePrimaryColor : DcColors.messageSecondaryColor)

        if !msg.isInfo {
            bottomLabel.attributedText = getFormattedBottomLine(message: msg)
        }
        messageLabel.delegate = self
    }

    func getFormattedBottomLine(message: DcMsg) -> NSAttributedString {
        var timestampAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(for: .caption1, weight: .regular),
            .foregroundColor: DcColors.grayDateColor,
            .paragraphStyle: NSParagraphStyle()
        ]

        let text = NSMutableAttributedString()
        if message.fromContactId == Int(DC_CONTACT_ID_SELF) {
            if let style = NSMutableParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle {
                style.alignment = .right
                timestampAttributes[.paragraphStyle] = style
            }

            text.append(NSAttributedString(string: message.formattedSentDate(), attributes: timestampAttributes))

            if message.showPadlock() {
                attachPadlock(to: text)
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

    private func attachPadlock(to text: NSMutableAttributedString) {
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(named: "ic_lock")
        imageAttachment.image?.accessibilityIdentifier = String.localized("encrypted_message")
        let imageString = NSMutableAttributedString(attachment: imageAttachment)
        imageString.addAttributes([NSAttributedString.Key.baselineOffset: -1], range: NSRange(location: 0, length: 1))
        text.append(NSAttributedString(string: " "))
        text.append(imageString)
    }

    private func attachSendingState(_ state: Int, to text: NSMutableAttributedString) {
        let imageAttachment = NSTextAttachment()
        var offset = -4


        switch Int32(state) {
        case DC_STATE_OUT_PENDING, DC_STATE_OUT_PREPARING:
            imageAttachment.image = #imageLiteral(resourceName: "ic_hourglass_empty_white_36pt").scaleDownImage(toMax: 16)?.maskWithColor(color: DcColors.grayDateColor)
            imageAttachment.image?.accessibilityIdentifier = String.localized("a11y_delivery_status_sending")
            offset = -2
        case DC_STATE_OUT_DELIVERED:
            imageAttachment.image = #imageLiteral(resourceName: "ic_done_36pt").scaleDownImage(toMax: 18)
            imageAttachment.image?.accessibilityIdentifier = String.localized("a11y_delivery_status_delivered")
        case DC_STATE_OUT_MDN_RCVD:
            imageAttachment.image = #imageLiteral(resourceName: "ic_done_all_36pt").scaleDownImage(toMax: 18)
            imageAttachment.image?.accessibilityIdentifier = String.localized("a11y_delivery_status_read")
            text.append(NSAttributedString(string: " "))
        case DC_STATE_OUT_FAILED:
            imageAttachment.image = #imageLiteral(resourceName: "ic_error_36pt").scaleDownImage(toMax: 16)
            imageAttachment.image?.accessibilityIdentifier = String.localized("a11y_delivery_status_error")
            offset = -2
        default:
            imageAttachment.image = nil
        }

        let imageString = NSMutableAttributedString(attachment: imageAttachment)
        imageString.addAttributes([.baselineOffset: offset],
                                  range: NSRange(location: 0, length: 1))
        text.append(imageString)
    }

    override public func prepareForReuse() {
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
        baseDelegate?.phoneNumberTapped(number: phoneNumber)
    }

    public func didSelectURL(_ url: URL) {
        logger.debug("did select URL")
        baseDelegate?.urlTapped(url: url)
    }

    public func didSelectTransitInformation(_ transitInformation: [String: String]) {}

    public func didSelectMention(_ mention: String) {}

    public func didSelectHashtag(_ hashtag: String) {}

    public func didSelectCustom(_ pattern: String, match: String?) {}
}

// MARK: - BaseMessageCellDelegate
// this delegate contains possible events from base cells or from derived cells
public protocol BaseMessageCellDelegate: class {
    func commandTapped(command: String) // `/command`
    func phoneNumberTapped(number: String)
    func urlTapped(url: URL) // url is eg. `https://foo.bar`
    func imageTapped(indexPath: IndexPath)
    func avatarTapped(indexPath: IndexPath)

}

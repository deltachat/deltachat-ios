import UIKit
import DcCore

public class BaseMessageCell: UITableViewCell {

    // horizontal message constraints for received messages
    private var leadingConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var trailingConstraintEditingMode: NSLayoutConstraint?
    private var leadingConstraintGroup: NSLayoutConstraint?
    private var gotoOriginalLeftConstraint: NSLayoutConstraint?

    // horizontal message constraints for sent messages
    private var leadingConstraintCurrentSender: NSLayoutConstraint?
    private var leadingConstraintCurrentSenderEditingMode: NSLayoutConstraint?
    private var trailingConstraintCurrentSender: NSLayoutConstraint?
    private var gotoOriginalRightConstraint: NSLayoutConstraint?

    private var mainContentBelowTopLabelConstraint: NSLayoutConstraint?
    private var mainContentUnderTopLabelConstraint: NSLayoutConstraint?
    private var mainContentAboveActionBtnConstraint: NSLayoutConstraint?
    private var mainContentUnderBottomLabelConstraint: NSLayoutConstraint?
    private var mainContentViewLeadingConstraint: NSLayoutConstraint?
    private var mainContentViewTrailingConstraint: NSLayoutConstraint?
    private var actionBtnZeroHeightConstraint: NSLayoutConstraint?
    private var actionBtnTrailingConstraint: NSLayoutConstraint?

    public var mainContentViewHorizontalPadding: CGFloat {
        get {
            return mainContentViewLeadingConstraint?.constant ?? 0
        }
        set {
            mainContentViewLeadingConstraint?.constant = newValue
            mainContentViewTrailingConstraint?.constant = -newValue
        }
    }

    // if set to true topLabel overlaps the main content
    public var topCompactView: Bool {
        get {
            return mainContentUnderTopLabelConstraint?.isActive ?? false
        }
        set {
            mainContentBelowTopLabelConstraint?.isActive = !newValue
            mainContentUnderTopLabelConstraint?.isActive = newValue
            topLabel.backgroundColor = newValue ?
                DcColors.systemMessageBackgroundColor :
                UIColor(alpha: 0, red: 0, green: 0, blue: 0)
        }
    }

    // if set to true bottomLabel overlaps the main content
    public var bottomCompactView: Bool {
        get {
            return mainContentUnderBottomLabelConstraint?.isActive ?? false
        }
        set {
            mainContentAboveActionBtnConstraint?.isActive = !newValue
            mainContentUnderBottomLabelConstraint?.isActive = newValue
        }
    }

    public var showBottomLabelBackground: Bool {
        didSet {
            statusView.backgroundColor = showBottomLabelBackground ?
                DcColors.systemMessageBackgroundColor :
                UIColor(alpha: 0, red: 0, green: 0, blue: 0)
        }
    }

    public var isActionButtonHidden: Bool {
        get {
            return actionButton.isHidden
        }
        set {
            mainContentAboveActionBtnConstraint?.constant = newValue ? -2 : 8
            actionBtnZeroHeightConstraint?.isActive = newValue
            actionBtnTrailingConstraint?.isActive = !newValue
            actionButton.isHidden = newValue
        }
    }

    public var isTransparent: Bool = false

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
        view.enabledDetectors = [.url, .phoneNumber, .command]
        let attributes = [
            NSAttributedString.Key.foregroundColor: view.tintColor!,
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
            NSAttributedString.Key.underlineColor: view.tintColor!
        ]
        view.label.setAttributes(attributes, detector: .url)
        view.label.setAttributes(attributes, detector: .phoneNumber)
        view.label.setAttributes(attributes, detector: .command)
        view.isUserInteractionEnabled = true
        view.isAccessibilityElement = false
        return view
    }()

    let avatarSize = 34.0
    lazy var avatarView: InitialsBadge = {
        let view = InitialsBadge(size: avatarSize)
        view.setColor(UIColor.gray)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        view.isHidden = true
        view.isUserInteractionEnabled = true
        view.isAccessibilityElement = false
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

    lazy var actionButton: DynamicFontButton = {
        let button = DynamicFontButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(.systemBlue, for: .normal)
        button.setTitleColor(.gray, for: .highlighted)
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.titleLabel?.textAlignment = .left
        button.contentHorizontalAlignment = .left
        button.addTarget(self, action: #selector(onActionButtonTapped), for: .touchUpInside)
        button.titleLabel?.font = UIFont.preferredFont(for: .body, weight: .regular)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        button.accessibilityLabel = String.localized("show_full_message")
        return button
    }()

    private let gotoOriginalWidth = CGFloat(32)
    lazy var gotoOriginalButton: UIButton = {
        let button = UIButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.constraintHeightTo(gotoOriginalWidth),
            button.constraintWidthTo(gotoOriginalWidth)
        ])
        button.addTarget(self, action: #selector(onGotoOriginal), for: .touchUpInside)
        button.backgroundColor = DcColors.gotoButtonBackgroundColor
        button.setImage(UIImage(systemName: "chevron.right")?.sd_tintedImage(with: DcColors.gotoButtonFontColor), for: .normal)
        button.layer.cornerRadius = gotoOriginalWidth / 2
        button.layer.masksToBounds = true
        button.accessibilityLabel = String.localized("show_in_chat")

        return button
    }()

    let statusView = StatusView()

    lazy var messageBackgroundContainer: BackgroundContainer = {
        let container = BackgroundContainer()
        container.image = UIImage(color: UIColor.blue)
        container.contentMode = .scaleToFill
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isUserInteractionEnabled = true
        return container
    }()

    let reactionsView: ReactionsView

    private var showSelectionBackground: Bool
    private var timer: Timer?

    private var dcContextId: Int?
    private var dcMsgId: Int?
    var a11yDcType: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {

        reactionsView = ReactionsView()
        reactionsView.translatesAutoresizingMaskIntoConstraints = false

        statusView.translatesAutoresizingMaskIntoConstraints = false

        showSelectionBackground = false
        showBottomLabelBackground = false
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)

        reactionsView.addTarget(self, action: #selector(BaseMessageCell.reactionsViewTapped(_:)), for: .touchUpInside)
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
        messageBackgroundContainer.addSubview(actionButton)
        messageBackgroundContainer.addSubview(statusView)
        contentView.addSubview(avatarView)
        contentView.addSubview(gotoOriginalButton)

        contentView.addConstraints([
            avatarView.constraintAlignLeadingTo(contentView, paddingLeading: 2),
            avatarView.constraintAlignBottomTo(messageBackgroundContainer),
            avatarView.constraintWidthTo(avatarSize, priority: .defaultHigh),
            avatarView.constraintHeightTo(avatarSize, priority: .defaultHigh),
            topLabel.constraintAlignTopTo(messageBackgroundContainer, paddingTop: 6),
            topLabel.constraintAlignLeadingTo(messageBackgroundContainer, paddingLeading: 8),
            topLabel.constraintAlignTrailingMaxTo(messageBackgroundContainer, paddingTrailing: 8),
            messageBackgroundContainer.constraintAlignTopTo(contentView, paddingTop: 3),
            actionButton.constraintAlignLeadingTo(messageBackgroundContainer, paddingLeading: 12),
            statusView.constraintAlignLeadingMaxTo(messageBackgroundContainer, paddingLeading: 8),
            statusView.constraintAlignTrailingTo(messageBackgroundContainer, paddingTrailing: 8),
            statusView.constraintToBottomOf(actionButton, paddingTop: 8, priority: .defaultHigh),
            statusView.constraintAlignBottomTo(messageBackgroundContainer, paddingBottom: 6),
            gotoOriginalButton.constraintCenterYTo(messageBackgroundContainer),
        ])

        gotoOriginalLeftConstraint = gotoOriginalButton.constraintAlignLeadingTo(messageBackgroundContainer, paddingLeading: -(gotoOriginalWidth+8))
        gotoOriginalLeftConstraint?.isActive = false
        gotoOriginalRightConstraint = gotoOriginalButton.constraintToTrailingOf(contentView, paddingLeading: -(gotoOriginalWidth+8))
        gotoOriginalRightConstraint?.isActive = false

        leadingConstraint = messageBackgroundContainer.constraintAlignLeadingTo(contentView, paddingLeading: 6)
        bottomConstraint = messageBackgroundContainer.constraintAlignBottomTo(contentView, paddingBottom: 3)
        bottomConstraint?.isActive = true
        leadingConstraintGroup = messageBackgroundContainer.constraintToTrailingOf(avatarView, paddingLeading: 2)
        trailingConstraint = messageBackgroundContainer.constraintAlignTrailingMaxTo(contentView, paddingTrailing: 50)
        trailingConstraintEditingMode = messageBackgroundContainer.constraintAlignTrailingMaxTo(contentView, paddingTrailing: 6)
        leadingConstraintCurrentSender = messageBackgroundContainer.constraintAlignLeadingMaxTo(contentView, paddingLeading: 50)
        leadingConstraintCurrentSenderEditingMode = messageBackgroundContainer.constraintAlignLeadingMaxTo(contentView, paddingLeading: 6)
        trailingConstraintCurrentSender = messageBackgroundContainer.constraintAlignTrailingTo(contentView, paddingTrailing: 6)

        mainContentViewLeadingConstraint = mainContentView.constraintAlignLeadingTo(messageBackgroundContainer)
        mainContentViewTrailingConstraint = mainContentView.constraintAlignTrailingTo(messageBackgroundContainer)
        mainContentViewLeadingConstraint?.isActive = true
        mainContentViewTrailingConstraint?.isActive = true

        mainContentBelowTopLabelConstraint = mainContentView.constraintToBottomOf(topLabel, paddingTop: 6)
        mainContentUnderTopLabelConstraint = mainContentView.constraintAlignTopTo(messageBackgroundContainer)
        mainContentAboveActionBtnConstraint = actionButton.constraintToBottomOf(mainContentView, paddingTop: 8, priority: .defaultHigh)
        mainContentUnderBottomLabelConstraint = mainContentView.constraintAlignBottomTo(messageBackgroundContainer, paddingBottom: 0, priority: .defaultHigh)

        actionBtnZeroHeightConstraint = actionButton.constraintHeightTo(0)
        actionBtnTrailingConstraint = actionButton.constraintAlignTrailingTo(messageBackgroundContainer, paddingTrailing: 12)

        topCompactView = false
        bottomCompactView = false
        showBottomLabelBackground = false
        isActionButtonHidden = true

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onAvatarTapped))
        gestureRecognizer.numberOfTapsRequired = 1
        avatarView.addGestureRecognizer(gestureRecognizer)

        let messageLabelGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        messageLabelGestureRecognizer.numberOfTapsRequired = 1
        messageLabel.addGestureRecognizer(messageLabelGestureRecognizer)

        let quoteViewGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onQuoteTapped))
        quoteViewGestureRecognizer.numberOfTapsRequired = 1
        quoteView.addGestureRecognizer(quoteViewGestureRecognizer)

        let statusGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onStatusTapped))
        statusGestureRecognizer.numberOfTapsRequired = 1
        statusView.addGestureRecognizer(statusGestureRecognizer)

        contentView.addSubview(reactionsView)

        let reactionsViewConstraints = [
            messageBackgroundContainer.leadingAnchor.constraint(lessThanOrEqualTo: reactionsView.leadingAnchor, constant: -10),
            messageBackgroundContainer.trailingAnchor.constraint(equalTo: reactionsView.trailingAnchor, constant: 10),
            messageBackgroundContainer.bottomAnchor.constraint(equalTo: reactionsView.bottomAnchor, constant: -20)
        ]

        NSLayoutConstraint.activate(reactionsViewConstraints)

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

    @objc func onGotoOriginal() {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            baseDelegate?.gotoOriginal(indexPath: indexPath)
        }
    }

    @objc func onQuoteTapped() {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            baseDelegate?.quoteTapped(indexPath: indexPath)
        }
    }

    @objc func onActionButtonTapped() {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            baseDelegate?.actionButtonTapped(indexPath: indexPath)
        }
    }

    @objc func onStatusTapped() {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            baseDelegate?.statusTapped(indexPath: indexPath)
        }
    }
    public override func willTransition(to state: UITableViewCell.StateMask) {
        super.willTransition(to: state)
        // while the content view gets intended by the appearance of the edit control,
        // we're adapting the the padding of the messages on the left side of the screen
        if state == .showingEditControl {
            if trailingConstraint?.isActive ?? false {
                trailingConstraint?.isActive = false
                trailingConstraintEditingMode?.isActive = true
            }
            if leadingConstraintCurrentSender?.isActive ?? false {
                leadingConstraintCurrentSender?.isActive = false
                leadingConstraintCurrentSenderEditingMode?.isActive = true
            }
        } else {
            if trailingConstraintEditingMode?.isActive ?? false {
                trailingConstraintEditingMode?.isActive = false
                trailingConstraint?.isActive = true
            }
            if leadingConstraintCurrentSenderEditingMode?.isActive ?? false {
                leadingConstraintCurrentSenderEditingMode?.isActive = false
                leadingConstraintCurrentSender?.isActive = true
            }
        }
    }

    public override func setSelected(_ selected: Bool, animated: Bool) {
         super.setSelected(selected, animated: animated)
         if selected && showSelectionBackground {
             selectedBackgroundView?.backgroundColor = DcColors.chatBackgroundColor.withAlphaComponent(0.5)
         } else {
             selectedBackgroundView?.backgroundColor = .clear
         }
     }

    // update classes inheriting BaseMessageCell first before calling super.update(...)
    func update(dcContext: DcContext, msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, searchText: String?, highlight: Bool) {
        let fromContact = dcContext.getContact(id: msg.fromContactId)
        if msg.isFromCurrentSender {
            topLabel.text = msg.isForwarded ? String.localized("forwarded_message") : nil
            let topLabelTextColor: UIColor
            if msg.isForwarded {
                if topCompactView {
                    topLabelTextColor = DcColors.coreDark05
                } else {
                    topLabelTextColor = DcColors.unknownSender
                }
            } else {
                topLabelTextColor = DcColors.defaultTextColor
            }
            topLabel.textColor = topLabelTextColor
            leadingConstraint?.isActive = false
            leadingConstraintGroup?.isActive = false
            trailingConstraint?.isActive = false
            trailingConstraintEditingMode?.isActive = false
            leadingConstraintCurrentSender?.isActive = !isEditing
            leadingConstraintCurrentSenderEditingMode?.isActive = isEditing
            trailingConstraintCurrentSender?.isActive = true
            gotoOriginalLeftConstraint?.isActive = true
            gotoOriginalRightConstraint?.isActive = false
        } else {
            topLabel.text = msg.isForwarded ? String.localized("forwarded_message") :
                showName ? msg.getSenderName(fromContact, markOverride: true) : nil
            let topLabelTextColor: UIColor
            if msg.isForwarded {
                if topCompactView {
                    topLabelTextColor = DcColors.coreDark05
                } else {
                    topLabelTextColor = DcColors.unknownSender
                }
            } else if showName {
                topLabelTextColor = fromContact.color
            } else {
                topLabelTextColor = DcColors.defaultTextColor
            }
            topLabel.textColor = topLabelTextColor
            leadingConstraintCurrentSender?.isActive = false
            leadingConstraintCurrentSenderEditingMode?.isActive = false
            trailingConstraintCurrentSender?.isActive = false
            if showName {
                leadingConstraint?.isActive = false
                leadingConstraintGroup?.isActive = true
            } else {
                leadingConstraintGroup?.isActive = false
                leadingConstraint?.isActive = true
            }
            trailingConstraint?.isActive = !isEditing
            trailingConstraintEditingMode?.isActive = isEditing
            gotoOriginalLeftConstraint?.isActive = false
            gotoOriginalRightConstraint?.isActive = true
        }

        if showAvatar {
            avatarView.isHidden = false
            avatarView.setName(msg.getSenderName(fromContact))
            avatarView.setColor(fromContact.color)
            if let profileImage = fromContact.profileImage {
                avatarView.setImage(profileImage)
            }
        } else {
            avatarView.isHidden = true
        }

        gotoOriginalButton.isHidden = msg.originalMessageId == 0

        let downloadState = msg.downloadState
        let hasHtml = msg.hasHtml
        let hasWebxdc =  msg.type == DC_MSG_WEBXDC
        
        switch downloadState {
        case DC_DOWNLOAD_AVAILABLE:
            actionButton.setTitle(String.localized("download"), for: .normal)
            isActionButtonHidden = false
        case DC_DOWNLOAD_FAILURE:
            actionButton.setTitle(String.localized("download_failed"), for: .normal)
            isActionButtonHidden = false
        case DC_DOWNLOAD_IN_PROGRESS:
            actionButton.isEnabled = false
            actionButton.setTitle(String.localized("downloading"), for: .normal)
            isActionButtonHidden = false
        default:
            if hasHtml {
                actionButton.setTitle(String.localized("show_full_message"), for: .normal)
                isActionButtonHidden = false
            } else if hasWebxdc {
                actionButton.setTitle(String.localized("start_app"), for: .normal)
                isActionButtonHidden = false
            } else {
                isActionButtonHidden = true
            }
        }

        messageBackgroundContainer.update(rectCorners: messageStyle,
                                          color: getBackgroundColor(dcContext: dcContext, message: msg))

        if !msg.isInfo {
            var tintColor: UIColor
            if showBottomLabelBackground {
                tintColor = DcColors.coreDark05
            } else if msg.isFromCurrentSender {
                tintColor = DcColors.checkmarkGreen
            } else {
                tintColor = DcColors.incomingMessageSecondaryTextColor
            }

            statusView.update(message: msg, tintColor: tintColor)
            let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                guard let self else { return }

                self.statusView.dateLabel.text = msg.formattedSentDate()
            }

            self.timer = timer
        }

        if let quoteText = msg.quoteText {
            quoteView.isHidden = false
            quoteView.quote.text = quoteText

            if let quoteMsg = msg.quoteMessage {
                let isWebxdc = quoteMsg.type == DC_MSG_WEBXDC
                let quoteImage = isWebxdc ? quoteMsg.getWebxdcPreviewImage() : quoteMsg.image
                quoteView.setImagePreview(quoteImage)
                quoteView.setRoundedCorners(isWebxdc)
                if quoteMsg.isForwarded {
                    quoteView.senderTitle.text = String.localized("forwarded_message")
                    quoteView.senderTitle.textColor = DcColors.unknownSender
                    quoteView.citeBar.backgroundColor = DcColors.unknownSender
                } else {
                    let contact = dcContext.getContact(id: quoteMsg.fromContactId)
                    quoteView.senderTitle.text = quoteMsg.getSenderName(contact, markOverride: true)
                    quoteView.senderTitle.textColor = contact.color
                    quoteView.citeBar.backgroundColor = contact.color
                }

            }
        } else {
            quoteView.isHidden = true
        }

        messageLabel.attributedText = getFormattedText(messageText: msg.text, searchText: searchText, highlight: highlight)
        messageLabel.delegate = self

        if let reactions = dcContext.getMessageReactions(messageId: msg.id) {
            reactionsView.isHidden = false
            reactionsView.configure(with: reactions)
            bottomConstraint?.constant = -20
        } else {
            reactionsView.isHidden = true
            bottomConstraint?.constant = -3
        }

        self.dcContextId = dcContext.id
        self.dcMsgId = msg.id
    }

    private func getFormattedText(messageText: String?, searchText: String?, highlight: Bool) -> NSAttributedString? {
        if let messageText = messageText {
            var fontSize = UIFont.preferredFont(for: .body, weight: .regular).pointSize
            let charCount = messageText.count
            if charCount <= 8 && messageText.containsOnlyEmoji { // render as jumbomoji
                if charCount <= 2 {
                    fontSize *= 3.0
                } else if charCount <= 4 {
                    fontSize *= 2.5
                } else if charCount <= 6 {
                    fontSize *= 1.75
                } else {
                    fontSize *= 1.35
                }
            }

            let fontAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: DcColors.defaultTextColor
            ]
            let mutableAttributedString = NSMutableAttributedString(string: messageText, attributes: fontAttributes)

            if let searchText = searchText {
                let ranges = messageText.ranges(of: searchText, options: .caseInsensitive)
                for range in ranges {
                    let nsRange = NSRange(range, in: messageText)
                    mutableAttributedString.addAttribute(.font, value: UIFont.preferredFont(for: .body, weight: .semibold), range: nsRange)
                    if highlight {
                        mutableAttributedString.addAttribute(.backgroundColor, value: DcColors.highlight, range: nsRange)
                    }
                }
            }
            return mutableAttributedString
        }
        return nil
    }

    public override func accessibilityElementDidBecomeFocused() {
        logger.info("jit-rendering accessibility string")  // jit-rendering is needed as the reactions summary require quite some database calls
        guard let dcContextId, let dcMsgId else { return }
        let dcContext = DcAccounts.shared.get(id: dcContextId)
        let msg = dcContext.getMessage(id: dcMsgId)
        let reactions = dcContext.getMessageReactions(messageId: msg.id)

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
        if let a11yDcType {
            additionalAccessibilityString = "\(a11yDcType), "
        }

        var reactionsString = ""
        if let reactions {
            reactionsString = ", " + String.localized(stringID: "n_reactions", parameter: reactions.reactionsByContact.count) + ": "
            for (contactId, reactions) in reactions.reactionsByContact {
                reactionsString += dcContext.getContact(id: contactId).displayName + ": " + reactions.joined(separator: " ") + ", "
            }
        }

        accessibilityLabel = "\(topLabelAccessibilityString) " +
            "\(quoteAccessibilityString) " +
            "\(additionalAccessibilityString) " +
            "\(messageLabelAccessibilityString) " +
            "\(StatusView.getAccessibilityString(message: msg))" +
            "\(reactionsString) "
    }

    func getBackgroundColor(dcContext: DcContext, message: DcMsg) -> UIColor {
        var backgroundColor: UIColor
        if isTransparent {
            backgroundColor = UIColor.init(alpha: 0, red: 0, green: 0, blue: 0)
        } else if message.isFromCurrentSender {
            backgroundColor =  DcColors.messagePrimaryColor
        } else {
            backgroundColor = DcColors.messageSecondaryColor
        }
        return backgroundColor
    }

    func getTextOffset(of text: String?) -> CGFloat {
        guard let text = text else { return 0 }
        let offsetInLabel = messageLabel.label.offsetOfSubstring(text)
        if offsetInLabel == 0 {
            return 0
        }

        let labelTop = CGPoint(x: messageLabel.label.bounds.minX, y: messageLabel.label.bounds.minY)
        let point = messageLabel.label.convert(labelTop, to: self)
        return point.y + offsetInLabel
    }

    override public func prepareForReuse() {
        accessibilityLabel = nil
        textLabel?.text = nil
        textLabel?.attributedText = nil
        topLabel.text = nil
        topLabel.attributedText = nil
        avatarView.reset()
        messageBackgroundContainer.prepareForReuse()
        statusView.prepareForReuse()
        baseDelegate = nil
        messageLabel.text = nil
        messageLabel.attributedText = nil
        messageLabel.delegate = nil
        quoteView.prepareForReuse()
        actionButton.isEnabled = true
        showSelectionBackground = false
        reactionsView.prepareForReuse()
        timer?.invalidate()
        timer = nil
        dcContextId = nil
        dcMsgId = nil
    }

    @objc func reactionsViewTapped(_ sender: Any?) {
        guard let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) else { return }

        baseDelegate?.reactionsTapped(indexPath: indexPath)
    }
}

// MARK: - MessageLabelDelegate
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
            baseDelegate?.urlTapped(url: url, indexPath: indexPath)
        }
    }

    public func didSelectTransitInformation(_ transitInformation: [String: String]) {}

    public func didSelectMention(_ mention: String) {}

    public func didSelectHashtag(_ hashtag: String) {}

    public func didSelectCommand(_ command: String) {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            baseDelegate?.commandTapped(command: command, indexPath: indexPath)
        }
    }

    public func didSelectCustom(_ pattern: String, match: String?) {}
}

extension BaseMessageCell: SelectableCell {
    public func showSelectionBackground(_ show: Bool) {
        showSelectionBackground = show
    }
}

// MARK: - BaseMessageCellDelegate
// this delegate contains possible events from base cells or from derived cells
public protocol BaseMessageCellDelegate: AnyObject {
    func commandTapped(command: String, indexPath: IndexPath) // `/command`
    func phoneNumberTapped(number: String, indexPath: IndexPath)
    func urlTapped(url: URL, indexPath: IndexPath) // url is eg. `https://foo.bar`
    func imageTapped(indexPath: IndexPath, previewError: Bool)
    func avatarTapped(indexPath: IndexPath)
    func textTapped(indexPath: IndexPath)
    func quoteTapped(indexPath: IndexPath)
    func actionButtonTapped(indexPath: IndexPath)
    func statusTapped(indexPath: IndexPath)
    func gotoOriginal(indexPath: IndexPath)
    func reactionsTapped(indexPath: IndexPath)
}

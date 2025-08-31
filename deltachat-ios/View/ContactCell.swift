import UIKit
import DcCore

protocol ContactCellDelegate: AnyObject {
    func onLongTap(at indexPath: IndexPath)
}

class ContactCell: UITableViewCell {

    static let reuseIdentifier = "contact_cell_reuse_identifier"
    static var cellHeight: CGFloat {
        let textHeight = UIFont.preferredFont(forTextStyle: .headline).pointSize + UIFont.preferredFont(forTextStyle: .subheadline).pointSize + 24
        if textHeight > 74.5 {
            return textHeight
        }
        return 74.5
    }

    var isLargeText: Bool {
        return UIFont.preferredFont(forTextStyle: .body).pointSize > 36
    }

    weak var delegate: ContactCellDelegate?
    private let badgeSize: CGFloat = 54
    private let imgSize: CGFloat = 20

    lazy var toplineStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            spacerView,
            mutedIndicator,
            locationStreamingIndicator,
            timeLabel,
            pinnedIndicator])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 4
        return stackView
    }()

    lazy var bottomlineStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [subtitleLabel, deliveryStatusIndicator, contactRequest, archivedIndicator, unreadMessageCounter])
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.alignment = .center
        return stackView
    }()

    lazy var avatar: InitialsBadge = {
        let badge = InitialsBadge(size: badgeSize)
        badge.setColor(UIColor.lightGray)
        badge.isAccessibilityElement = false
        return badge
    }()

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingTail
        label.textColor = DcColors.defaultTextColor
        label.font = UIFont.preferredFont(for: .body, weight: .medium)
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1), for: .horizontal)
        label.isAccessibilityElement = false
        return label
    }()

    private lazy var spacerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1), for: .horizontal)
        view.isAccessibilityElement = false
        return view
    }()

    lazy var pinnedIndicator: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 16).isActive = true
        view.tintColor = DcColors.middleGray
        view.image = UIImage(systemName: "pin.fill")?.withRenderingMode(.alwaysTemplate)
        view.isHidden = true
        view.contentMode = .scaleAspectFit
        view.isAccessibilityElement = false
        return view
    }()

    lazy var mutedIndicator: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 16).isActive = true
        view.tintColor = DcColors.middleGray
        view.image = UIImage(systemName: "speaker.slash.fill")?.withRenderingMode(.alwaysTemplate)
        view.isHidden = true
        view.contentMode = .scaleAspectFit
        view.isAccessibilityElement = false
        return view
    }()

    lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = DcColors.middleGray
        label.textAlignment = .right
        label.setContentHuggingPriority(.defaultHigh, for: NSLayoutConstraint.Axis.horizontal)
        label.isAccessibilityElement = false
        return label
    }()

    lazy var locationStreamingIndicator: UIImageView = {
        let view = LocationStreamingIndicator(height: 16)
        view.isHidden = true
        view.contentMode = .scaleAspectFit
        view.isAccessibilityElement = false
        return view
    }()

    lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = DcColors.middleGray
        label.lineBreakMode = .byTruncatingTail
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.isAccessibilityElement = false
        return label
    }()

    private lazy var deliveryStatusIndicator: UIImageView = {
        let view = UIImageView()
        view.isHidden = true
        view.isAccessibilityElement = false
        return view
    }()

    private lazy var archivedIndicator: UIView = {
        return createTagLabel(tag: String.localized("chat_archived_label"))
    }()

    private lazy var contactRequest: UIView = {
        return createTagLabel(tag: String.localized("chat_request_label"))
    }()

    private let unreadMessageCounter: MessageCounter = {
        let view = MessageCounter(count: 0, size: 20)
        view.isHidden = true
        view.isAccessibilityElement = false
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
        configureCompressionPriority()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory {
            configureCompressionPriority()
        }
    }

    private func createTagLabel(tag: String) -> UIView {
        let tintColor = UIColor(hexString: "848ba7")
        let label = UILabel()
        label.font = label.font.withSize(14)
        label.text = tag
        label.textColor = tintColor
        label.setContentHuggingPriority(.defaultHigh, for: NSLayoutConstraint.Axis.horizontal) // needed so label does not expand to available space
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 2), for: NSLayoutConstraint.Axis.horizontal)
        let view = UIView()
        view.layer.borderColor = tintColor.cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = 2
        view.isHidden = true

        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4).isActive = true
        label.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4).isActive = true
        label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        label.isAccessibilityElement = false
        return view
    }
    private func configureCompressionPriority() {
        if isLargeText {
            timeLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1), for: .horizontal)
            subtitleLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 10), for: .horizontal)
        } else {
            timeLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 10), for: .horizontal)
            subtitleLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1), for: .horizontal)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        subtitleLabel.isHidden = false
    }

    private func setupSubviews() {
        let margin: CGFloat = 10
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = DcColors.selectBackground
        isAccessibilityElement = true

        avatar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatar)

        contentView.addConstraints([
            avatar.constraintWidthTo(badgeSize),
            avatar.constraintHeightTo(badgeSize),
            avatar.constraintAlignLeadingTo(contentView, paddingLeading: badgeSize / 4),
            avatar.constraintAlignTopTo(contentView, paddingTop: badgeSize / 4, priority: .defaultLow),
            avatar.constraintAlignBottomTo(contentView, paddingBottom: badgeSize / 4, priority: .defaultLow),
            avatar.constraintCenterYTo(contentView, priority: .required),
        ])

        deliveryStatusIndicator.translatesAutoresizingMaskIntoConstraints = false
        deliveryStatusIndicator.heightAnchor.constraint(equalToConstant: 20).isActive = true
        deliveryStatusIndicator.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let verticalStackView = UIStackView()
        verticalStackView.translatesAutoresizingMaskIntoConstraints = false
        verticalStackView.clipsToBounds = true

        contentView.addSubview(verticalStackView)
        verticalStackView.addArrangedSubview(toplineStackView)
        verticalStackView.addArrangedSubview(bottomlineStackView)
        verticalStackView.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: margin).isActive = true
        verticalStackView.constraintCenterYTo(avatar, priority: .required).isActive = true
        verticalStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin).isActive = true
        verticalStackView.axis = .vertical

        toplineStackView.addConstraints([
            pinnedIndicator.constraintHeightTo(titleLabel.font.pointSize * 1.2),
            mutedIndicator.constraintHeightTo(titleLabel.font.pointSize * 1.2),
            locationStreamingIndicator.constraintHeightTo(titleLabel.font.pointSize * 1.2)
        ])

        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(onLongTap))
        contentView.addGestureRecognizer(gestureRecognizer)
    }

    @objc private func onLongTap(sender: UILongPressGestureRecognizer) {
        if sender.state == UIGestureRecognizer.State.began,
           let tableView = self.superview as? UITableView,
           let indexPath = tableView.indexPath(for: self) {
            delegate?.onLongTap(at: indexPath)
        }
    }

    func setImage(_ img: UIImage) {
        avatar.setImage(img)
    }

    func resetBackupImage() {
        avatar.setColor(UIColor.clear)
        avatar.setName("")
    }

    func setBackupImage(name: String, color: UIColor) {
        avatar.setColor(color)
        avatar.setName(name)
    }

    private func setStatusIndicators(unreadCount: Int, status: Int, visibility: Int32, isLocationStreaming: Bool, isChatMuted: Bool = false, isAccountMuted: Bool = false, isContactRequest: Bool, isArchiveLink: Bool) {
        unreadMessageCounter.backgroundColor = isChatMuted || isAccountMuted || isArchiveLink  ? DcColors.unreadBadgeMuted : DcColors.unreadBadge

        if isLargeText {
            unreadMessageCounter.setCount(unreadCount)
            unreadMessageCounter.isHidden = unreadCount == 0 || isContactRequest
            pinnedIndicator.isHidden = true
            deliveryStatusIndicator.isHidden = true
            archivedIndicator.isHidden = true
            contactRequest.isHidden = true
            return
        }

        if visibility == DC_CHAT_VISIBILITY_ARCHIVED {
            pinnedIndicator.isHidden = true
            unreadMessageCounter.setCount(unreadCount)
            unreadMessageCounter.isHidden = isContactRequest || unreadCount <= 0
            deliveryStatusIndicator.isHidden = true
            archivedIndicator.isHidden = false
        } else if unreadCount > 0 {
            pinnedIndicator.isHidden = !(visibility == DC_CHAT_VISIBILITY_PINNED)
            unreadMessageCounter.setCount(unreadCount)
            unreadMessageCounter.isHidden = isContactRequest
            deliveryStatusIndicator.isHidden = true
            archivedIndicator.isHidden = true
        } else {
            switch Int32(status) {
            case DC_STATE_OUT_PENDING, DC_STATE_OUT_PREPARING:
                deliveryStatusIndicator.image = UIImage(named: "ic_hourglass_empty_white_36pt")?.maskWithColor(color: DcColors.middleGray)
            case DC_STATE_OUT_DELIVERED:
                deliveryStatusIndicator.image = UIImage(named: "ic_done_36pt")
            case DC_STATE_OUT_FAILED:
                deliveryStatusIndicator.image = UIImage(named: "ic_error_36pt")
            case DC_STATE_OUT_MDN_RCVD:
                deliveryStatusIndicator.image = UIImage(named: "ic_done_all_36pt")
            default:
                deliveryStatusIndicator.image = nil
            }

            pinnedIndicator.isHidden = !(visibility == DC_CHAT_VISIBILITY_PINNED)
            unreadMessageCounter.isHidden = true
            deliveryStatusIndicator.isHidden = deliveryStatusIndicator.image == nil ? true : false
            archivedIndicator.isHidden = true
        }

        contactRequest.isHidden = !isContactRequest
        mutedIndicator.isHidden = !isChatMuted
        locationStreamingIndicator.isHidden = !isLocationStreaming
    }

    func setTimeLabel(_ timestamp: Int64?) {
        let timestamp = timestamp ?? 0
        if timestamp != 0 {
            timeLabel.isHidden = false
            timeLabel.text = DateUtils.getBriefRelativeTimeSpanString(timeStamp: Double(timestamp))
        } else {
            timeLabel.isHidden = true
            timeLabel.text = nil
        }
    }

    func setColor(_ color: UIColor) {
        avatar.setColor(color)
    }

    // use this update-method to update cell in cellForRowAt whenever it is possible - other set-methods will be set private in progress
    func updateCell(cellViewModel: AvatarCellViewModel) {

        // subtitle
        subtitleLabel.attributedText = cellViewModel.subtitle.boldAt(indexes: cellViewModel.subtitleHighlightIndexes, fontSize: subtitleLabel.font.pointSize)
        var unreadMessages = 0
        var isContactRequest = false
        var isArchived = false

        switch cellViewModel.type {
        case .chat(let chatData):
            let chat = cellViewModel.dcContext.getChat(chatId: chatData.chatId)
            unreadMessages = chatData.unreadMessages
            isContactRequest = chat.isContactRequest
            let visibility = chat.visibility
            isArchived = visibility == DC_CHAT_VISIBILITY_ARCHIVED
            // text bold if chat contains unread messages - otherwise hightlight search results if needed
            if chatData.chatId == DC_CHAT_ID_ARCHIVED_LINK {
                titleLabel.text = cellViewModel.title
                // for archived links, move unread counter to top line (bottom line is not used)
                // this hack is also the reason we do not reuse the archive-link together with the normal chats
                bottomlineStackView.removeArrangedSubview(unreadMessageCounter)
                toplineStackView.addArrangedSubview(unreadMessageCounter)
            } else if chatData.unreadMessages > 0 {
                titleLabel.attributedText = cellViewModel.title.bold(fontSize: titleLabel.font.pointSize)
            } else {
                titleLabel.attributedText = cellViewModel.title.boldAt(indexes: cellViewModel.titleHighlightIndexes, fontSize: titleLabel.font.pointSize)
            }
            if visibility == DC_CHAT_VISIBILITY_PINNED {
                backgroundColor = DcColors.deaddropBackground
            } else {
                backgroundColor = DcColors.contactCellBackgroundColor
            }
            if let img = chat.profileImage {
                resetBackupImage()
                setImage(img)
            } else {
                setBackupImage(name: chat.name, color: chat.color)
            }
            let recentlySeen = DcUtils.showRecentlySeen(context: cellViewModel.dcContext, chat: chat)
            avatar.setRecentlySeen(recentlySeen)
            setTimeLabel(chatData.summary.timestamp)
            setStatusIndicators(unreadCount: chatData.unreadMessages,
                                status: chatData.summary.state,
                                visibility: visibility,
                                isLocationStreaming: chat.isSendingLocations,
                                isChatMuted: chat.isMuted,
                                isAccountMuted: cellViewModel.dcContext.isMuted(),
                                isContactRequest: isContactRequest,
                                isArchiveLink: chatData.chatId == DC_CHAT_ID_ARCHIVED_LINK)

        case .contact(let contactData):
            let contact = cellViewModel.dcContext.getContact(id: contactData.contactId)
            titleLabel.attributedText = cellViewModel.title.boldAt(indexes: cellViewModel.titleHighlightIndexes, fontSize: titleLabel.font.pointSize)
            subtitleLabel.isHidden = contact.isKeyContact

            if let profileImage = contact.profileImage {
                avatar.setImage(profileImage)
            } else {
                avatar.setName(cellViewModel.title)
                avatar.setColor(contact.color)
            }
            avatar.setRecentlySeen(contact.wasSeenRecently)
            setTimeLabel(0)
            setStatusIndicators(unreadCount: 0,
                                status: 0,
                                visibility: 0,
                                isLocationStreaming: false,
                                isContactRequest: false,
                                isArchiveLink: false)
        case .profile:
            let contact = cellViewModel.dcContext.getContact(id: Int(DC_CONTACT_ID_SELF))
            titleLabel.text = cellViewModel.title
            subtitleLabel.text = cellViewModel.subtitle
            if let profileImage = contact.profileImage {
                avatar.setImage(profileImage)
            } else {
                avatar.setName(cellViewModel.title)
                avatar.setColor(contact.color)
            }
            avatar.setRecentlySeen(false)
            setTimeLabel(0)
            setStatusIndicators(unreadCount: 0,
                                status: 0,
                                visibility: 0,
                                isLocationStreaming: false,
                                isContactRequest: false,
                                isArchiveLink: false)
        }

        accessibilityLabel = (titleLabel.text != nil ? ((titleLabel.text ?? "")+"\n") : "")
            + (isContactRequest ? (String.localized("chat_request_label")+"\n") : "")
            + (isArchived ? (String.localized("chat_archived_label")+"\n") : "")
            + (unreadMessages > 0 ? (String.localized(stringID: "n_messages", parameter: unreadMessages)+"\n") : "")
            + (timeLabel.text != nil ? ((timeLabel.text ?? "")+"\n") : "")
            + (subtitleLabel.text != nil ? ((subtitleLabel.text ?? "")+"\n") : "")
    }
}

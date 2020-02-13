import UIKit

protocol ContactCellDelegate: class {
    func onAvatarTapped(at index: Int)
}

class ContactCell: UITableViewCell {

    static let reuseIdentifier = "contact_cell_reuse_identifier"

    public static let cellHeight: CGFloat = 74.5
    weak var delegate: ContactCellDelegate?
    var rowIndex = -1 // TODO: is this still needed?
    private let badgeSize: CGFloat = 54
    private let imgSize: CGFloat = 20

    lazy var toplineStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, timeLabel])
        stackView.axis = .horizontal
        return stackView
    }()

    lazy var bottomlineStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [subtitleLabel, deliveryStatusIndicator])
        stackView.axis = .horizontal
        stackView.spacing = 10
        return stackView
    }()

    lazy var avatar: InitialsBadge = {
        let badge = InitialsBadge(size: badgeSize)
        badge.setColor(UIColor.lightGray)
        badge.isAccessibilityElement = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(onAvatarTapped))
        badge.addGestureRecognizer(tap)
        return badge
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = DcColors.defaultTextColor
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1), for: NSLayoutConstraint.Axis.horizontal)
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(hexString: "848ba7")
        label.textAlignment = .right
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 2), for: NSLayoutConstraint.Axis.horizontal)
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(hexString: "848ba7")
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let deliveryStatusIndicator: UIImageView = {
        let view = UIImageView()
        view.tintColor = UIColor.green
        view.isHidden = true
        return view
    }()

    private let archivedIndicator: UIView = {
        let tintColor = UIColor(hexString: "848ba7")
        let label = UILabel()
        label.font = label.font.withSize(14)
        label.text = String.localized("chat_archived_label")
        label.textColor = tintColor
        label.setContentHuggingPriority(.defaultHigh, for: NSLayoutConstraint.Axis.horizontal) // needed so label does not expand to available space
        let view = UIView()
        view.layer.borderColor = tintColor.cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = 4

        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4).isActive = true
        label.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4).isActive = true
        label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        return view
    }()

    private let unreadMessageCounter: MessageCounter = {
        let view = MessageCounter(count: 0, size: 20)
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = DcColors.contactCellBackgroundColor
        contentView.backgroundColor = DcColors.contactCellBackgroundColor
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        let margin: CGFloat = 10

        avatar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatar)

        contentView.addConstraints([
            avatar.constraintWidthTo(badgeSize),
            avatar.constraintHeightTo(badgeSize),
            avatar.constraintAlignLeadingTo(contentView, paddingLeading: badgeSize / 4),
            avatar.constraintCenterYTo(contentView),
        ])

        deliveryStatusIndicator.translatesAutoresizingMaskIntoConstraints = false
        deliveryStatusIndicator.heightAnchor.constraint(equalToConstant: 20).isActive = true
        deliveryStatusIndicator.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let verticalStackView = UIStackView()
        verticalStackView.translatesAutoresizingMaskIntoConstraints = false
        verticalStackView.clipsToBounds = true

        contentView.addSubview(verticalStackView)
        verticalStackView.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: margin).isActive = true
        verticalStackView.centerYAnchor.constraint(equalTo: avatar.centerYAnchor).isActive = true
        verticalStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin).isActive = true
        verticalStackView.axis = .vertical
        verticalStackView.addArrangedSubview(toplineStackView)
        verticalStackView.addArrangedSubview(bottomlineStackView)
    }

    func setVerified(isVerified: Bool) {
        avatar.setVerified(isVerified)
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

    func setUnreadMessageCounter(_ count: Int) {
        unreadMessageCounter.setCount(count)
    }

    func setIsArchived(_ isArchived: Bool) {
        if isArchived {
            bottomlineStackView.removeArrangedSubview(deliveryStatusIndicator)
            bottomlineStackView.addArrangedSubview(archivedIndicator)
        } else {
            bottomlineStackView.removeArrangedSubview(archivedIndicator)
            bottomlineStackView.addArrangedSubview(deliveryStatusIndicator)
        }
    }

    func setDeliveryStatusIndicator(_ status: Int) {
        var indicatorImage: UIImage?
        switch Int32(status) {
        case DC_STATE_OUT_PENDING, DC_STATE_OUT_PREPARING:
            indicatorImage = #imageLiteral(resourceName: "ic_hourglass_empty_36pt").withRenderingMode(.alwaysTemplate)
            deliveryStatusIndicator.tintColor = UIColor.black.withAlphaComponent(0.5)
        case DC_STATE_OUT_DELIVERED:
            indicatorImage = #imageLiteral(resourceName: "ic_done_36pt").withRenderingMode(.alwaysTemplate)
            deliveryStatusIndicator.tintColor = DcColors.checkmarkGreen
        case DC_STATE_OUT_FAILED:
            indicatorImage = #imageLiteral(resourceName: "ic_error_36pt").withRenderingMode(.alwaysTemplate)
            deliveryStatusIndicator.tintColor = UIColor.red
        case DC_STATE_OUT_MDN_RCVD:
            indicatorImage = #imageLiteral(resourceName: "ic_done_all_36pt").withRenderingMode(.alwaysTemplate)
            deliveryStatusIndicator.tintColor = DcColors.checkmarkGreen
        default:
            break
        }
        if indicatorImage != nil && unreadMessageCounter.isHidden {
            deliveryStatusIndicator.isHidden = false
        } else {
            deliveryStatusIndicator.isHidden = true
        }
        deliveryStatusIndicator.image = indicatorImage
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

    @objc func onAvatarTapped() {
        if rowIndex == -1 {
            return
        }
        delegate?.onAvatarTapped(at: rowIndex)
    }

    func updateCell(cellViewModel: AvatarCellViewModel) {
        // subtitle
        subtitleLabel.attributedText = cellViewModel.subtitle.boldAt(indexes: cellViewModel.subtitleHighlightIndexes, fontSize: subtitleLabel.font.pointSize)

        switch cellViewModel.type {
        case .CHAT(let chatData):
            let chat = DcChat(id: chatData.chatId)

            // text bold if chat contains unread messages - otherwise hightlight search results if needed
            if chatData.unreadMessages > 0 {
                titleLabel.attributedText = NSAttributedString(string: cellViewModel.title, attributes: [ .font: UIFont.systemFont(ofSize: 16, weight: .bold) ])
            } else {
                titleLabel.attributedText = cellViewModel.title.boldAt(indexes: cellViewModel.titleHighlightIndexes, fontSize: titleLabel.font.pointSize)
            }

            if let img = chat.profileImage {
                resetBackupImage()
                setImage(img)
            } else {
              setBackupImage(name: chat.name, color: chat.color)
            }
            setVerified(isVerified: chat.isVerified)
            setTimeLabel(chatData.summary.timestamp)
            setUnreadMessageCounter(chatData.unreadMessages)
            setDeliveryStatusIndicator(chatData.summary.state)
            setIsArchived(chat.isArchived)

        case .CONTACT(let contactData):
            let contact = DcContact(id: contactData.contactId)
            titleLabel.attributedText = cellViewModel.title.boldAt(indexes: cellViewModel.titleHighlightIndexes, fontSize: titleLabel.font.pointSize)
            avatar.setName(cellViewModel.title)
            avatar.setColor(contact.color)
        }
    }
}

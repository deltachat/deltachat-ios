import UIKit

// TODO: integrate InitialsBadge in here

protocol ContactCellDelegate: class {
    func onAvatarTapped(at index: Int)
}

class ContactCell: UITableViewCell {

    public static let cellSize: CGFloat = 72
    weak var delegate: ContactCellDelegate?
    var rowIndex = -1
    private let initialsLabelSize: CGFloat = 54
    private let imgSize: CGFloat = 20

    let avatar: UIView = {
        let avatar = UIView()
        return avatar
    }()

    lazy var imgView: UIImageView = {
        let imgView = UIImageView()
        let img = UIImage(named: "verified")
        imgView.isHidden = true
        imgView.image = img
        imgView.bounds = CGRect(
            x: 0,
            y: 0,
            width: imgSize, height: imgSize
        )
        return imgView
    }()

    lazy var initialsLabel: UILabel = {
        let initialsLabel = UILabel()
        initialsLabel.textAlignment = NSTextAlignment.center
        initialsLabel.textColor = UIColor.white
        initialsLabel.font = UIFont.systemFont(ofSize: 22)
        initialsLabel.backgroundColor = UIColor.green
        let initialsLabelCornerRadius = (initialsLabelSize - 6) / 2
        initialsLabel.layer.cornerRadius = initialsLabelCornerRadius
        initialsLabel.clipsToBounds = true
        return initialsLabel
    }()

    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = DcColors.defaultTextColor
        // label.makeBorder()
        return label

    }()

    let emailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(hexString: "848ba7")
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(hexString: "848ba7")
        label.textAlignment = .right
        // label.makeBorder()
        return label
    }()

    private let deliveryStatusIndicator: UIImageView = {
        let view = UIImageView()
        view.tintColor = UIColor.green
        view.isHidden = true
        return view
    }()

    private let unreadMessageCounter: MessageCounter = {
        let view = MessageCounter(count: 0, size: 20)
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.backgroundColor = DcColors.chatBackgroundColor
        setupSubviews()
    }

    private func setupSubviews() {
        let margin: CGFloat = 10

        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        avatar.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.widthAnchor.constraint(equalToConstant: initialsLabelSize - 6).isActive = true
        initialsLabel.heightAnchor.constraint(equalToConstant: initialsLabelSize - 6).isActive = true
        // avatar.backgroundColor = .red

        avatar.widthAnchor.constraint(equalToConstant: initialsLabelSize).isActive = true
        avatar.heightAnchor.constraint(equalToConstant: initialsLabelSize).isActive = true

        avatar.addSubview(initialsLabel)
        contentView.addSubview(avatar)

        initialsLabel.topAnchor.constraint(equalTo: avatar.topAnchor, constant: 3).isActive = true
        initialsLabel.leadingAnchor.constraint(equalTo: avatar.leadingAnchor, constant: 3).isActive = true
        initialsLabel.trailingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: -3).isActive = true

        avatar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin).isActive = true
        avatar.center.y = contentView.center.y
        avatar.center.x += initialsLabelSize / 2
        avatar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: margin).isActive = true
        avatar.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -margin).isActive = true
        initialsLabel.center = avatar.center

        deliveryStatusIndicator.translatesAutoresizingMaskIntoConstraints = false
        deliveryStatusIndicator.heightAnchor.constraint(equalToConstant: 20).isActive = true
        deliveryStatusIndicator.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let myStackView = UIStackView()
        myStackView.translatesAutoresizingMaskIntoConstraints = false
        myStackView.clipsToBounds = true

        let toplineStackView = UIStackView()
        toplineStackView.axis = .horizontal

        let bottomLineStackView = UIStackView()
        bottomLineStackView.axis = .horizontal

        toplineStackView.addArrangedSubview(nameLabel)
        toplineStackView.addArrangedSubview(timeLabel)

        bottomLineStackView.addArrangedSubview(emailLabel)
        bottomLineStackView.addArrangedSubview(deliveryStatusIndicator)
        bottomLineStackView.addArrangedSubview(unreadMessageCounter)

        contentView.addSubview(myStackView)
        myStackView.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: margin).isActive = true
        myStackView.centerYAnchor.constraint(equalTo: avatar.centerYAnchor).isActive = true
        myStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin).isActive = true
        myStackView.axis = .vertical
        myStackView.addArrangedSubview(toplineStackView)
        myStackView.addArrangedSubview(bottomLineStackView)

        avatar.addSubview(imgView)

        imgView.center.x = avatar.center.x + (avatar.frame.width / 2) + imgSize
        imgView.center.y = avatar.center.y + (avatar.frame.height / 2) + imgSize

        if delegate != nil {
            let tap = UITapGestureRecognizer(target: self, action: #selector(onAvatarTapped))
            avatar.addGestureRecognizer(tap)
        }
    }

    func setVerified(isVerified: Bool) {
        imgView.isHidden = !isVerified
    }

    func setImage(_ img: UIImage) {
        if let resizedImg = img.resizeImage(targetSize: CGSize(width: initialsLabelSize - 6, height: initialsLabelSize - 6)) {
            let attachment = NSTextAttachment()
            attachment.image = resizedImg
            initialsLabel.attributedText = NSAttributedString(attachment: attachment)
        }
    }

    func resetBackupImage() {
        initialsLabel.text = ""
        setColor(UIColor.clear)
    }

    func setBackupImage(name: String, color: UIColor) {
        let text = Utils.getInitials(inputName: name)

        initialsLabel.textAlignment = .center
        initialsLabel.text = text

        setColor(color)
    }

    func setUnreadMessageCounter(_ count: Int) {
        unreadMessageCounter.setCount(count)
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
            timeLabel.text = DateUtils.getBriefRelativeTimeSpanString(timeStamp: Int(timestamp))
        } else {
            timeLabel.isHidden = true
            timeLabel.text = nil
        }
    }

    func setColor(_ color: UIColor) {
        initialsLabel.backgroundColor = color
    }

    @objc func onAvatarTapped() {
        if let delegate = delegate {
            if rowIndex == -1 {
                return
            }
            delegate.onAvatarTapped(at: rowIndex)
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

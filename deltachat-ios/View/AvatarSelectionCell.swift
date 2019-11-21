import UIKit

class AvatarSelectionCell: UITableViewCell {
    let badgeSize: CGFloat = 72
    static let cellSize: CGFloat = 98
    let downscaleDefaultImage: CGFloat = 0.6

    var onAvatarTapped: (() -> Void)?

    lazy var defaultImage: UIImage = {
        if let image = UIImage(named: "camera") {
            return image.invert()
        }
        return UIImage()
    }()

    lazy var badge: InitialsBadge = {
        let badge = InitialsBadge(size: badgeSize)
        badge.layer.cornerRadius = badgeSize / 2
        badge.clipsToBounds = true
        badge.setColor(UIColor.lightGray)
        return badge
    }()

    lazy var hintLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = DcColors.defaultTextColor
        label.text = String.localized("pref_profile_photo")
        return label
    }()

    init(chat: DcChat) {
        super.init(style: .default, reuseIdentifier: nil)
        setAvatar(for: chat)
        setupSubviews()
    }

    init(context: DcContext?) {
        super.init(style: .default, reuseIdentifier: nil)
        setAvatar(image: context?.getSelfAvatarImage(), with: self.defaultImage, downscale: downscaleDefaultImage)
        setupSubviews()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        contentView.addSubview(badge)
        badge.alignTrailingToAnchor(contentView.layoutMarginsGuide.trailingAnchor)
        badge.alignTopToAnchor(contentView.layoutMarginsGuide.topAnchor)

        contentView.addSubview(hintLabel)
        hintLabel.alignLeadingToAnchor(contentView.layoutMarginsGuide.leadingAnchor)
        hintLabel.alignTopToAnchor(contentView.layoutMarginsGuide.topAnchor)
        hintLabel.alignTrailingToAnchor(badge.leadingAnchor)
        hintLabel.alignBottomToAnchor(contentView.layoutMarginsGuide.bottomAnchor)

        let touchListener = UILongPressGestureRecognizer(target: self, action: #selector(onBadgeTouched))
        touchListener.minimumPressDuration = 0
        badge.addGestureRecognizer(touchListener)
    }

    func onInitialsChanged(text: String?) {
        if badge.showsInitials() {
            badge.setName(text ?? "")
        }
    }

    @objc func onBadgeTouched(gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            badge.alpha = 0.7
        case .ended:
            badge.alpha = 1
            onAvatarTapped?()
        case .cancelled:
            badge.alpha = 1
        default:
            break
        }
    }

    func setAvatar(for chat: DcChat) {
        if let image = chat.profileImage {
            badge = InitialsBadge(image: image, size: badgeSize)
        } else {
            badge = InitialsBadge(name: chat.name, color: chat.color, size: badgeSize)
        }
        badge.setVerified(chat.isVerified)
    }

    func setAvatar(image: UIImage?, with defaultImage: UIImage?, downscale: CGFloat? = nil) {
        if let image = image {
            badge = InitialsBadge(image: image, size: badgeSize)
        } else if let defaultImage = defaultImage {
            badge = InitialsBadge(image: defaultImage, size: badgeSize, downscale: downscale)
            badge.backgroundColor = DcColors.grayTextColor
        }
    }
}

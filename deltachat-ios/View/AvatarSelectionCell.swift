import UIKit
import DcCore

class AvatarSelectionCell: UITableViewCell {
    let badgeSize: CGFloat = 72

    var onAvatarTapped: (() -> Void)?

    lazy var defaultImage: UIImage = {
        if let image = UIImage(named: "camera") {
            return image.invert()
        }
        return UIImage()
    }()

    lazy var badge: InitialsBadge = {
        let badge = InitialsBadge(size: badgeSize)
        badge.setColor(UIColor.lightGray)
        return badge
    }()

    lazy var hintLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = DcColors.defaultTextColor
        label.text = String.localized("pref_profile_photo")
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    init(image: UIImage?) {
        super.init(style: .default, reuseIdentifier: nil)
        setAvatar(image: image)
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
        badge.alignBottomToAnchor(contentView.layoutMarginsGuide.bottomAnchor)

        contentView.addSubview(hintLabel)
        hintLabel.alignLeadingToAnchor(contentView.layoutMarginsGuide.leadingAnchor)
        hintLabel.alignTopToAnchor(contentView.layoutMarginsGuide.topAnchor)
        hintLabel.alignTrailingToAnchor(badge.leadingAnchor)
        hintLabel.alignBottomToAnchor(contentView.layoutMarginsGuide.bottomAnchor, priority: .defaultLow)

        let touchListener = UILongPressGestureRecognizer(target: self, action: #selector(onBadgeTouched))
        touchListener.minimumPressDuration = 0
        badge.addGestureRecognizer(touchListener)
        selectionStyle = .none
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

    func setAvatar(image: UIImage?) {
        if let image = image {
            badge.setImage(image)
        } else {
            badge = InitialsBadge(image: defaultImage, size: badgeSize)
            badge.backgroundColor = DcColors.grayTextColor
        }
    }
}

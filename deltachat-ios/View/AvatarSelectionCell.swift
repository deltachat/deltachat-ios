import UIKit
import DcCore

class AvatarSelectionCell: UITableViewCell {
    let badgeSize: CGFloat = 72
    private var avatarSet = false

    var onAvatarTapped: (() -> Void)?

    lazy var defaultImage: UIImage = {
        return UIImage(named: "camera") ?? UIImage()
    }()

    lazy var badge: InitialsBadge = {
        let badge = InitialsBadge(size: badgeSize)
        badge.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return badge
    }()

    lazy var hintLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = DcColors.defaultTextColor
        label.text = String.localized("pref_profile_photo")
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var container: UIStackView = {
        let container = UIStackView(arrangedSubviews: [hintLabel, badge])
        container.axis = .horizontal
        container.alignment = .center
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
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
        contentView.addSubview(container)
        container.alignTopToAnchor(contentView.layoutMarginsGuide.topAnchor)
        container.alignBottomToAnchor(contentView.layoutMarginsGuide.bottomAnchor)
        container.alignLeadingToAnchor(contentView.layoutMarginsGuide.leadingAnchor)
        container.alignTrailingToAnchor(contentView.layoutMarginsGuide.trailingAnchor)

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
            avatarSet = true
        } else {
            badge.setImage(defaultImage)
            badge.setColor(UIColor.lightGray)
            avatarSet = false
        }
    }

    func isAvatarSet() -> Bool {
        return avatarSet
    }
}

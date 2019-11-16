import UIKit

class AvatarEditTextCell: UITableViewCell {
    let badgeSize: CGFloat = 72
    static let cellSize: CGFloat = 98

    var onTextChanged: ((String) -> Void)? // use this callback to update editButton in navigationController
    var onAvatarTapped: (() -> Void)?

    lazy var badge: InitialsBadge = {
        let badge = InitialsBadge(size: badgeSize)
        badge.layer.cornerRadius = badgeSize / 2
        badge.clipsToBounds = true
        badge.setColor(UIColor.lightGray)
        return badge
    }()

    lazy var inputField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .none
        textField.becomeFirstResponder()
        textField.autocorrectionType = .no
        textField.addTarget(self, action: #selector(inputFieldChanged), for: .editingChanged)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textAlignment = .right
        return textField
    }()

    lazy var hintLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = DcColors.defaultTextColor
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.text = String.localized("pref_your_name")
        label.textAlignment = .right
        return label
    }()

    init(chat: DcChat) {
        super.init(style: .default, reuseIdentifier: nil)
        setAvatar(for: chat)
        setupSubviews()
    }


    init(context: DcContext, defaultImage: UIImage, downscale: CGFloat? = nil) {
        super.init(style: .default, reuseIdentifier: nil)
        setSelfAvatar(context: context, with: defaultImage, downscale: downscale)
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

        badge.alignLeadingToAnchor(contentView.layoutMarginsGuide.leadingAnchor)
        badge.alignTopToAnchor(contentView.layoutMarginsGuide.topAnchor)
        contentView.addSubview(inputField)

        inputField.alignLeadingToAnchor(badge.trailingAnchor, paddingLeading: 15)
        inputField.addConstraints(heightConstant: CGFloat(20))
        inputField.alignTrailingToAnchor(contentView.layoutMarginsGuide.trailingAnchor)
        inputField.alignBottomToAnchor(contentView.layoutMarginsGuide.bottomAnchor, paddingBottom: 15)
        contentView.addSubview(hintLabel)

        hintLabel.alignTopToAnchor(contentView.layoutMarginsGuide.topAnchor)
        hintLabel.alignTrailingToAnchor(contentView.layoutMarginsGuide.trailingAnchor)
        hintLabel.addConstraints(heightConstant: CGFloat(20))

        let touchListener = UILongPressGestureRecognizer(target: self, action: #selector(onBadgeTouched))
        touchListener.minimumPressDuration = 0
        badge.addGestureRecognizer(touchListener)
    }

    @objc func inputFieldChanged() {
        let groupName = inputField.text ?? ""
        if badge.showsInitials() {
            badge.setName(groupName)
        }
        onTextChanged?(groupName)
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

    func getText() -> String {
        return inputField.text ?? ""
    }

    func setAvatar(for chat: DcChat) {
        if let image = chat.profileImage {
            badge = InitialsBadge(image: image, size: badgeSize)
        } else {
            badge = InitialsBadge(name: chat.name, color: chat.color, size: badgeSize)
        }
        badge.setVerified(chat.isVerified)
    }

    func setSelfAvatar(context: DcContext?, with defaultImage: UIImage?, downscale: CGFloat? = nil) {
        guard let context = context else {
            return
        }
        
        if let image = context.getSelfAvatarImage() {
            badge = InitialsBadge(image: image, size: badgeSize)
        } else if let defaultImage = defaultImage {
            badge = InitialsBadge(image: defaultImage, size: badgeSize, downscale: downscale)
            badge.backgroundColor = DcColors.grayTextColor
        }
    }
}

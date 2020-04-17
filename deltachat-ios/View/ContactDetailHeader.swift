import UIKit
import DcCore

class ContactDetailHeader: UIView {

    public static let headerHeight: CGFloat = 74.5

    let badgeSize: CGFloat = 54

    private lazy var avatar: InitialsBadge = {
        let badge = InitialsBadge(size: badgeSize)
        badge.setColor(UIColor.lightGray)
        badge.isAccessibilityElement = false
        return badge
    }()

    private var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = DcColors.defaultTextColor
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1), for: NSLayoutConstraint.Axis.horizontal)
        return label
    }()

    private var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(hexString: "848ba7")
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    init() {
        super.init(frame: .zero)
        backgroundColor = DcColors.contactCellBackgroundColor
        setupSubviews()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        let margin: CGFloat = 10
        let verticalStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])

        addSubview(avatar)
        addSubview(verticalStackView)

        avatar.translatesAutoresizingMaskIntoConstraints = false
        verticalStackView.translatesAutoresizingMaskIntoConstraints = false

        addConstraints([
            avatar.constraintWidthTo(badgeSize),
            avatar.constraintHeightTo(badgeSize),
            avatar.constraintAlignLeadingTo(self, paddingLeading: badgeSize / 4),
            avatar.constraintCenterYTo(self),
        ])


        verticalStackView.clipsToBounds = true
        verticalStackView.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: margin).isActive = true
        verticalStackView.centerYAnchor.constraint(equalTo: avatar.centerYAnchor).isActive = true
        verticalStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -margin).isActive = true
        verticalStackView.axis = .vertical
    }

    func updateDetails(title: String?, subtitle: String?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }

    func setImage(_ image: UIImage) {
        avatar.setImage(image)
    }

    func resetBackupImage() {
        avatar.setColor(UIColor.clear)
        avatar.setName("")
    }

    func setBackupImage(name: String, color: UIColor) {
        avatar.setColor(color)
        avatar.setName(name)
    }

    func setVerified(isVerified: Bool) {
        avatar.setVerified(isVerified)
    }
}

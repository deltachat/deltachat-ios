import UIKit
import DcCore

class ContactDetailHeader: UIView {

    var onAvatarTap: VoidFunction?
    var onSearchButtonTapped: VoidFunction?
    var onMuteButtonTapped: VoidFunction?

    public static let headerHeight: CGFloat = 74.5

    let badgeSize: CGFloat = 54

    private lazy var avatar: InitialsBadge = {
        let badge = InitialsBadge(size: badgeSize)
        badge.setColor(UIColor.lightGray)
        badge.isAccessibilityElement = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(avatarTapped(_:)))
        badge.addGestureRecognizer(tap)
        return badge
    }()

    private var titleLabel: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingTail
        label.textColor = DcColors.defaultTextColor
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1), for: NSLayoutConstraint.Axis.horizontal)
        label.adjustsFontForContentSizeCategory = true
        label.font = .preferredFont(forTextStyle: UIFont.TextStyle.headline)
        return label
    }()

    private var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = UIColor(hexString: "848ba7")
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private var searchButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(searchBtnTapped), for: .touchUpInside)
        button.backgroundColor = DcColors.defaultBackgroundColor
        button.setImage(UIImage(named: "ic_search")?.sd_tintedImage(with: .systemBlue), for: .normal)
        button.contentVerticalAlignment = .fill
        button.contentHorizontalAlignment = .fill
        button.contentMode = .scaleAspectFit
        button.imageEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 5, right: 6)
        button.layer.cornerRadius = 16
        button.layer.borderColor = DcColors.colorDisabled.cgColor
        button.layer.borderWidth = 1
        button.layer.masksToBounds = true
        button.constraintHeightTo(32).isActive = true
        button.constraintWidthTo(32).isActive = true
        return button
    }()

    private var muteButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(muteBtnTapped), for: .touchUpInside)
        button.backgroundColor = DcColors.defaultBackgroundColor
        if #available(iOS 13.0, *) {
            button.setImage(UIImage(systemName: "bell")?.sd_tintedImage(with: .systemBlue), for: .normal)
        } else {
            button.setImage(UIImage(named: "ic_notifications_on")?.sd_tintedImage(with: .systemBlue), for: .normal)
        }
        button.layer.cornerRadius = 16
        button.layer.borderColor = DcColors.colorDisabled.cgColor
        button.layer.borderWidth = 1
        button.layer.masksToBounds = true
        button.constraintHeightTo(32).isActive = true
        button.constraintWidthTo(32).isActive = true
        return button
    }()

    init() {
        super.init(frame: .zero)
        backgroundColor =  .clear
        setupSubviews()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        let margin: CGFloat = 10
        let verticalStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        let horizontalStackView = UIStackView(arrangedSubviews: [searchButton, muteButton])

        addSubview(avatar)
        addSubview(verticalStackView)
        addSubview(horizontalStackView)

        avatar.translatesAutoresizingMaskIntoConstraints = false
        verticalStackView.translatesAutoresizingMaskIntoConstraints = false
        horizontalStackView.translatesAutoresizingMaskIntoConstraints = false

        addConstraints([
            avatar.constraintWidthTo(badgeSize),
            avatar.constraintHeightTo(badgeSize),
            avatar.constraintAlignLeadingTo(self, paddingLeading: badgeSize / 4),
            avatar.constraintCenterYTo(self),
        ])


        verticalStackView.clipsToBounds = true
        verticalStackView.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: margin).isActive = true
        verticalStackView.centerYAnchor.constraint(equalTo: avatar.centerYAnchor).isActive = true
        verticalStackView.trailingAnchor.constraint(equalTo: horizontalStackView.leadingAnchor, constant: -margin).isActive = true
        verticalStackView.axis = .vertical

        horizontalStackView.axis = .horizontal
        horizontalStackView.distribution = .fillEqually
        horizontalStackView.alignment = .center
        horizontalStackView.constraintAlignLeadingToAnchor(verticalStackView.trailingAnchor).isActive = true
        horizontalStackView.constraintAlignTrailingToAnchor(trailingAnchor, paddingTrailing: margin).isActive = true
        horizontalStackView.constraintCenterYTo(self).isActive = true
        horizontalStackView.spacing = margin
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

    func setMuted(isMuted: Bool) {
        if #available(iOS 13.0, *) {
            muteButton.setImage(isMuted ? UIImage(systemName: "bell.slash")?.sd_tintedImage(with: .systemBlue) :
                                    UIImage(systemName: "bell")?.sd_tintedImage(with: .systemBlue),
                                for: .normal)
        } else {
            muteButton.setImage(isMuted ?
                                UIImage(named: "ic_notifications_off")?.sd_tintedImage(with: .systemBlue) :
                                    UIImage(named: "ic_notifications_on")?.sd_tintedImage(with: .systemBlue),
                                for: .normal)
        }
    }

    func showMuteButton(show: Bool) {
        muteButton.isHidden = !show
    }

    func showSearchButton(show: Bool) {
        searchButton.isHidden = !show
    }

    func setVerified(isVerified: Bool) {
        avatar.setVerified(isVerified)
    }

    @objc private func avatarTapped(_ sender: InitialsBadge) {
        onAvatarTap?()
    }

    @objc private func searchBtnTapped() {
        onSearchButtonTapped?()
    }

    @objc private func muteBtnTapped() {
        onMuteButtonTapped?()
    }

}

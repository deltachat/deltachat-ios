import UIKit
import DcCore

class ContactDetailHeader: UIView {

    var onAvatarTap: VoidFunction?
    var onSearchButtonTapped: VoidFunction?
    var onMuteButtonTapped: VoidFunction?

    public static let headerHeight: CGFloat = 74.5
    let badgeSize: CGFloat = 54
    var indicatorHeightConstraint: NSLayoutConstraint?

    private lazy var avatar: InitialsBadge = {
        let badge = InitialsBadge(size: badgeSize)
        badge.setColor(UIColor.lightGray)
        badge.isAccessibilityElement = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(avatarTapped(_:)))
        badge.addGestureRecognizer(tap)
        return badge
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingTail
        label.isUserInteractionEnabled = true
        label.textColor = DcColors.defaultTextColor
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1), for: .horizontal)
        label.adjustsFontForContentSizeCategory = true
        label.font = .preferredFont(forTextStyle: UIFont.TextStyle.headline)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private(set) lazy var titleLabelContainer: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, greenCheckmark, spacerView])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private(set) lazy var labelsContainer: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabelContainer, subtitleLabel])
        stackView.clipsToBounds = true
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var spacerView: UIView = {
        let view = UIView()
        view.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1), for: .horizontal)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isAccessibilityElement = false
        return view
    }()

    private lazy var greenCheckmark: UIImageView = {
        let imgView = UIImageView()
        let img = UIImage(named: "verified")
        imgView.isHidden = true
        imgView.image = img
        imgView.translatesAutoresizingMaskIntoConstraints = false
        imgView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imgView.isAccessibilityElement = false
        return imgView
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingTail
        label.isUserInteractionEnabled = true
        label.textColor = UIColor(hexString: "848ba7")
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1), for: .horizontal)
        label.adjustsFontForContentSizeCategory = true
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var searchButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(searchBtnTapped), for: .touchUpInside)
        button.backgroundColor = DcColors.profileCellBackgroundColor
        button.setImage(UIImage(named: "ic_search")?.sd_tintedImage(with: .systemBlue), for: .normal)
        button.contentVerticalAlignment = .fill
        button.contentHorizontalAlignment = .fill
        button.contentMode = .scaleAspectFit
        button.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.layer.cornerRadius = 20
        button.layer.borderColor = DcColors.colorDisabled.cgColor
        button.layer.borderWidth = 1
        button.layer.masksToBounds = true
        button.constraintHeightTo(40).isActive = true
        button.constraintWidthTo(40).isActive = true
        return button
    }()

    private lazy var muteButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(muteBtnTapped), for: .touchUpInside)
        button.backgroundColor = DcColors.profileCellBackgroundColor
        button.setImage(UIImage(named: "volume_on")?.sd_tintedImage(with: .systemBlue), for: .normal)
        button.contentVerticalAlignment = .fill
        button.contentHorizontalAlignment = .fill
        button.contentMode = .scaleAspectFit
        button.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.layer.cornerRadius = 20
        button.layer.borderColor = DcColors.colorDisabled.cgColor
        button.layer.borderWidth = 1
        button.layer.masksToBounds = true
        button.constraintHeightTo(40).isActive = true
        button.constraintWidthTo(40).isActive = true
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
        let lrMargin: CGFloat = 16
        let spacing: CGFloat = 10
        let horizontalStackView = UIStackView(arrangedSubviews: [searchButton, muteButton])

        addSubview(avatar)
        addSubview(labelsContainer)
        addSubview(horizontalStackView)

        avatar.translatesAutoresizingMaskIntoConstraints = false
        horizontalStackView.translatesAutoresizingMaskIntoConstraints = false

        addConstraints([
            avatar.constraintWidthTo(badgeSize),
            avatar.constraintHeightTo(badgeSize),
            avatar.constraintAlignLeadingTo(self, paddingLeading: lrMargin),
            avatar.constraintCenterYTo(self),
            greenCheckmark.constraintHeightTo(titleLabel.font.pointSize * 0.9),
            greenCheckmark.widthAnchor.constraint(equalTo: greenCheckmark.heightAnchor),
        ])

        labelsContainer.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: spacing).isActive = true
        labelsContainer.centerYAnchor.constraint(equalTo: avatar.centerYAnchor).isActive = true
        labelsContainer.trailingAnchor.constraint(equalTo: horizontalStackView.leadingAnchor, constant: -spacing).isActive = true

        horizontalStackView.axis = .horizontal
        horizontalStackView.distribution = .fillEqually
        horizontalStackView.alignment = .center
        horizontalStackView.constraintAlignTrailingToAnchor(trailingAnchor, paddingTrailing: lrMargin).isActive = true
        horizontalStackView.constraintCenterYTo(self).isActive = true
        horizontalStackView.spacing = spacing
    }

    func updateDetails(title: String?, subtitle: String?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }

    func setImage(_ image: UIImage) {
        avatar.setImage(image)
    }

    func setRecentlySeen(_ seen: Bool) {
        avatar.setRecentlySeen(seen)
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
        muteButton.setImage(isMuted ?
                            UIImage(named: "volume_off")?.sd_tintedImage(with: .systemBlue) :
                                UIImage(named: "volume_on")?.sd_tintedImage(with: .systemBlue),
                            for: .normal)
    }

    func showMuteButton(show: Bool) {
        muteButton.isHidden = !show
    }

    func showSearchButton(show: Bool) {
        searchButton.isHidden = !show
    }

    func setGreenCheckmark(greenCheckmark: Bool) {
        self.greenCheckmark.isHidden = !greenCheckmark
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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        searchButton.layer.borderColor = DcColors.colorDisabled.cgColor
        muteButton.layer.borderColor = DcColors.colorDisabled.cgColor
    }

}

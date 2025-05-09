import UIKit
import DcCore

class ContactDetailHeader: UIStackView {

    var onAvatarTap: VoidFunction?

    public static let headerHeight: CGFloat = 240

    private lazy var avatar: InitialsBadge = {
        let badge = InitialsBadge(size: 160)
        badge.setColor(UIColor.lightGray)
        badge.isAccessibilityElement = false
        badge.translatesAutoresizingMaskIntoConstraints = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(avatarTapped(_:)))
        badge.addGestureRecognizer(tap)
        return badge
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingTail
        label.textColor = DcColors.defaultTextColor

        let baseFont = UIFont.preferredFont(forTextStyle: .title1)
        if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitBold) {
            label.font = UIFont(descriptor: descriptor, size: descriptor.pointSize)
        }

        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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

    private(set) lazy var titleLabelContainer: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [UIView(), titleLabel, greenCheckmark, UIView()])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        axis = .vertical
        alignment = .center
        spacing = 12

        addArrangedSubview(UIView()) // spacer
        addArrangedSubview(avatar)
        addArrangedSubview(titleLabelContainer)
        addArrangedSubview(UIView()) // spacer

        addConstraints([
            greenCheckmark.constraintHeightTo(titleLabel.font.pointSize * 0.8),
            greenCheckmark.widthAnchor.constraint(equalTo: greenCheckmark.heightAnchor),
        ])
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateDetails(title: String?) {
        titleLabel.text = title
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

    func setGreenCheckmark(greenCheckmark: Bool) {
        self.greenCheckmark.isHidden = !greenCheckmark
    }

    @objc private func avatarTapped(_ sender: InitialsBadge) {
        onAvatarTap?()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
    }
}

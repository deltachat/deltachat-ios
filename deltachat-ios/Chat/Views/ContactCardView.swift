import UIKit
import DcCore

public class ContactCardView: UIView {

    private var imageWidthConstraint: NSLayoutConstraint?
    private var imageHeightConstraint: NSLayoutConstraint?

    private lazy var contactStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [profileImageView, nameLabel])
        stackView.axis = .horizontal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 8
        stackView.alignment = .center
        return stackView
    }()

    lazy var profileImageView: InitialsBadge = {
        let imageView = InitialsBadge(size: 50)
        isAccessibilityElement = false
        return imageView
    }()

    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 3
        label.lineBreakMode = .byCharWrapping
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        isAccessibilityElement = false
        return label
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(contactStackView)
        let widthConstraint = profileImageView.widthAnchor.constraint(equalToConstant: 50)
        let heightConstraint = profileImageView.heightAnchor.constraint(equalToConstant: 50)
        imageWidthConstraint = widthConstraint
        imageHeightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            contactStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contactStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contactStackView.topAnchor.constraint(equalTo: topAnchor),
            contactStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthConstraint,
            heightConstraint,
        ])
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func configure(message: DcMsg, dcContext: DcContext) {
        guard message.type == DC_MSG_VCARD,
              let file = message.file,
              let vcard = dcContext.parseVcard(path: file)?.first else { return }

        if let profileImageString = vcard.profileImage, let profileImage = UIImage.fromBase64(string: profileImageString) {
            profileImageView.setImage(profileImage)
        } else {
            let color = UIColor(hexString: vcard.color)
            profileImageView.setColor(color)
            profileImageView.setName(vcard.displayName)
        }

        nameLabel.text = vcard.displayName
    }

    public func configureAccessibilityLabel() -> String {
        return nameLabel.text ?? ""
    }

    public func prepareForReuse() {
    }
}

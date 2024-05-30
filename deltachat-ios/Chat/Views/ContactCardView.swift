import UIKit
import DcCore

public class ContactCardView: UIView {

    private var imageWidthConstraint: NSLayoutConstraint?
    private var imageHeightConstraint: NSLayoutConstraint?

    public var horizontalLayout: Bool {
        get {
            return contactStackView.axis == .horizontal
        }
        set {
            if newValue {
                contactStackView.axis = .horizontal
                imageWidthConstraint?.isActive = true
                imageHeightConstraint?.isActive = true
                contactStackView.alignment = .center
            } else {
                contactStackView.axis = .vertical
                imageWidthConstraint?.isActive = false
                imageHeightConstraint?.isActive = false
                contactStackView.alignment = .leading
            }
        }
    }

    // allow to automatically switch between small and large preview of a file,
    // depending on the file type, if false the view will be configured according to horizontalLayout Bool
    public var allowLayoutChange: Bool = true

    private lazy var contactStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [profileImageView, fileMetadataStackView])
        stackView.axis = .horizontal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 6
        return stackView
    }()

    lazy var profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        isAccessibilityElement = false
        return imageView
    }()

    private lazy var fileMetadataStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel, addressLabel])
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.clipsToBounds = true
        return stackView
    }()

    lazy var nameLabel: UILabel = {
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false
        return title
    }()

    private lazy var addressLabel: UILabel = {
        let subtitle = UILabel()
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.numberOfLines = 1
        isAccessibilityElement = false
        return subtitle
    }()

    convenience init() {
        self.init(frame: .zero)
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(contactStackView)
        contactStackView.fillSuperview()
        imageWidthConstraint = profileImageView.constraintWidthTo(50)
        imageHeightConstraint = profileImageView.constraintHeightTo(50 * 1.3, priority: .defaultLow)
        horizontalLayout = true
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func configure(message: DcMsg, dcContext: DcContext) {
        guard message.type == DC_MSG_VCARD,
              let file = message.file,
              let vcard = dcContext.parseVcard(path: file)?.first else { return }

        profileImageView.layer.cornerRadius = 0
        if let profileImageString = vcard.profileImage, let profileImage = UIImage.fromBase64(string: profileImageString) {
            profileImageView.image = profileImage
        } else {
            profileImageView.image = UIImage(named: "person.crop.circle")
            horizontalLayout = true
        }
        nameLabel.numberOfLines = 3
        nameLabel.lineBreakMode = .byCharWrapping
        nameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        nameLabel.text = vcard.displayName

        addressLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        addressLabel.text = vcard.addr
    }

    public func configureAccessibilityLabel() -> String {
        var accessibilityFileTitle = ""
        var accessiblityFileSubtitle = ""
        if let fileTitleText = nameLabel.text {
            accessibilityFileTitle = fileTitleText
        }
        if let subtitleText = addressLabel.text {
            accessiblityFileSubtitle = subtitleText
        }

        return "\(accessibilityFileTitle), \(accessiblityFileSubtitle)"
    }

    public func prepareForReuse() {
        profileImageView.image = nil
    }
}

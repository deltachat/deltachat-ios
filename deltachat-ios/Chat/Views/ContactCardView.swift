import UIKit
import DcCore

public class ContactCardView: UIView {

    private var imageWidthConstraint: NSLayoutConstraint?
    private var imageHeightConstraint: NSLayoutConstraint?

    public var horizontalLayout: Bool {
        get {
            return fileStackView.axis == .horizontal
        }
        set {
            if newValue {
                fileStackView.axis = .horizontal
                imageWidthConstraint?.isActive = true
                imageHeightConstraint?.isActive = true
                fileStackView.alignment = .center
            } else {
                fileStackView.axis = .vertical
                imageWidthConstraint?.isActive = false
                imageHeightConstraint?.isActive = false
                fileStackView.alignment = .leading
            }
        }
    }

    // allow to automatically switch between small and large preview of a file,
    // depending on the file type, if false the view will be configured according to horizontalLayout Bool
    public var allowLayoutChange: Bool = true

    private lazy var fileStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [fileImageView, fileMetadataStackView])
        stackView.axis = .horizontal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 6
        return stackView
    }()

    lazy var fileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        isAccessibilityElement = false
        return imageView
    }()

    private lazy var fileMetadataStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [fileTitle, fileSubtitle])
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.clipsToBounds = true
        return stackView
    }()

    lazy var fileTitle: UILabel = {
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false
        return title
    }()

    private lazy var fileSubtitle: UILabel = {
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
        addSubview(fileStackView)
        fileStackView.fillSuperview()
        imageWidthConstraint = fileImageView.constraintWidthTo(50)
        imageHeightConstraint = fileImageView.constraintHeightTo(50 * 1.3, priority: .defaultLow)
        horizontalLayout = true
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func configure(message: DcMsg) {
        guard message.type == DC_MSG_VCARD else { return }

        fileImageView.layer.cornerRadius = 0
        if let vcard = message.file {
            //TODO: get image date from vcard.profileImage
            fileImageView.image = UIImage(named: "ic_attach_file_36pt")
        } else {
            //TODO: Replace with SF Symbol `person.circle`
            fileImageView.image = UIImage(named: "ic_attach_file_36pt")
            horizontalLayout = true
        }
        fileTitle.numberOfLines = 3
        fileTitle.lineBreakMode = .byCharWrapping
        fileTitle.font = UIFont.preferredFont(forTextStyle: .headline)
        fileSubtitle.font = UIFont.preferredFont(forTextStyle: .caption2)
        fileTitle.text = message.filename
        fileSubtitle.text = message.getPrettyFileSize()

    }


    public func configureAccessibilityLabel() -> String {
        var accessibilityFileTitle = ""
        var accessiblityFileSubtitle = ""
        if let fileTitleText = fileTitle.text {
            accessibilityFileTitle = fileTitleText
        }
        if let subtitleText = fileSubtitle.text {
            accessiblityFileSubtitle = subtitleText
        }

        return "\(accessibilityFileTitle), \(accessiblityFileSubtitle)"
    }

    public func prepareForReuse() {
        fileImageView.image = nil
    }
}

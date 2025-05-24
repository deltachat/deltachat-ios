import UIKit
import DcCore
public class FileView: UIView {

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

    private lazy var defaultImage: UIImage = {
        let image = UIImage(named: "ic_attach_file_36pt")
        return image!
    }()

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
        self.setupSubviews()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    func setupSubviews() {
        addSubview(fileStackView)
        fileStackView.fillSuperview()
        imageWidthConstraint = fileImageView.constraintWidthTo(50)
        imageHeightConstraint = fileImageView.constraintHeightTo(50 * 1.3, priority: .defaultLow)
        horizontalLayout = true
    }

    public func configure(message: DcMsg, forceWebxdcSummary: String? = nil) {
        if message.type == DC_MSG_WEBXDC {
            configureWebxdc(message: message, forceWebxdcSummary: forceWebxdcSummary)
        } else if message.type == DC_MSG_FILE || message.isUnsupportedMediaFile {
            configureFile(message: message)
        } else {
            logger.error("Configuring message failed")
        }
    }

    private func configureWebxdc(message: DcMsg, forceWebxdcSummary: String?) {
        fileImageView.layer.cornerRadius = 8
        let dict = message.getWebxdcInfoDict()
        if let iconfilePath = dict["icon"] as? String {
            let blob = message.getWebxdcBlob(filename: iconfilePath)
            if !blob.isEmpty {
                fileImageView.image = UIImage(data: blob)?.sd_resizedImage(with: CGSize(width: 175, height: 175), scaleMode: .aspectFill)
            }
        }

        let document = dict["document"] as? String ?? ""
        let summary = dict["summary"] as? String ?? ""
        let name = dict["name"] as? String ?? "ErrName" // name should not be empty

        fileTitle.numberOfLines = 1
        fileTitle.lineBreakMode = .byTruncatingTail
        fileTitle.font = UIFont.preferredFont(forTextStyle: .headline)
        fileSubtitle.font = UIFont.preferredFont(forTextStyle: .body)
        fileTitle.text = document.isEmpty ? name : "\(document) – \(name)"
        fileSubtitle.text = forceWebxdcSummary ?? (summary.isEmpty ? String.localized("webxdc_app") : summary)
    }

    private func configureFile(message: DcMsg) {
        fileImageView.layer.cornerRadius = 0
        if let url = message.fileURL {
            generateThumbnailFor(url: url, placeholder: defaultImage)
        } else {
            fileImageView.image = defaultImage
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

    private func generateThumbnailFor(url: URL, placeholder: UIImage?) {
        if let pdfThumbnail = DcUtils.thumbnailFromPdf(withUrl: url) {
            fileImageView.image = pdfThumbnail
            horizontalLayout = allowLayoutChange ? false : horizontalLayout
        } else {
            let controller = UIDocumentInteractionController(url: url)
            fileImageView.image = controller.icons.first ?? placeholder
            horizontalLayout = allowLayoutChange ? true : horizontalLayout
        }
    }


}

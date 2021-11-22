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

    private lazy var fileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
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
        title.font = UIFont.preferredItalicFont(for: .body)
        title.translatesAutoresizingMaskIntoConstraints = false
        title.numberOfLines = 3
        title.lineBreakMode = .byCharWrapping
        isAccessibilityElement = false
        return title
    }()

    private lazy var fileSubtitle: UILabel = {
        let subtitle = UILabel()
        subtitle.font = UIFont.preferredItalicFont(for: .caption2)
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

    public func configure(message: DcMsg) {
        if let url = message.fileURL {
            generateThumbnailFor(url: url, placeholder: defaultImage)
        } else {
            fileImageView.image = defaultImage
            horizontalLayout = true
        }
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
        if let thumbnail = ThumbnailCache.shared.restoreImage(key: url.absoluteString) {
            fileImageView.image = thumbnail
            horizontalLayout = allowLayoutChange ? false : horizontalLayout
        } else if let pdfThumbnail = DcUtils.thumbnailFromPdf(withUrl: url) {
            fileImageView.image = pdfThumbnail
            horizontalLayout = allowLayoutChange ? false : horizontalLayout
            ThumbnailCache.shared.storeImage(image: pdfThumbnail, key: url.absoluteString)
        } else if url.pathExtension == "svg" {
            fileImageView.sd_setImage(with: url) { img, error, cacheType, imageURL in
                if error == nil, let img = img, let imageURL = imageURL {
                    self.horizontalLayout = self.allowLayoutChange ? false : self.horizontalLayout
                    ThumbnailCache.shared.storeImage(image: img, key: imageURL.absoluteString)
                } else {
                    self.loadDocumentThumbnail(url: url, placeholder: placeholder)
                }
                return
            }
        } else {
            loadDocumentThumbnail(url: url, placeholder: placeholder)
        }
    }
    
    private func loadDocumentThumbnail(url: URL, placeholder: UIImage?) {
        let controller = UIDocumentInteractionController(url: url)
        fileImageView.image = controller.icons.first ?? placeholder
        horizontalLayout = allowLayoutChange ? true : horizontalLayout
    }


}

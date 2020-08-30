import Foundation
import UIKit
import DcCore
import SDWebImage

class NewFileTextCell: BaseMessageCell {

    private lazy var defaultImage: UIImage = {
        let image = UIImage(named: "ic_attach_file_36pt")
        return image!
    }()

    private var imageWidthConstraint: NSLayoutConstraint?
    private var imageHeightConstraint: NSLayoutConstraint?
    private var spacer: NSLayoutConstraint?

    private var horizontalLayout: Bool {
        set {
            if newValue {
                fileStackView.axis = .horizontal
                imageWidthConstraint?.isActive = true
                imageHeightConstraint?.isActive = true
            } else {
                fileStackView.axis = .vertical
                imageWidthConstraint?.isActive = false
                imageHeightConstraint?.isActive = false
            }
        }
        get {
            return fileStackView.axis == .horizontal
        }
    }

    private lazy var fileStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [fileImageView, fileMetadataStackView])
        stackView.axis = .horizontal
        stackView.spacing = 6
        stackView.alignment = .center
        return stackView
    }()

    private lazy var fileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var fileMetadataStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [fileTitle, fileSubtitle])
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.clipsToBounds = true
        return stackView
    }()

    private lazy var fileTitle: UILabel = {
        let title = UILabel()
        title.font = UIFont.preferredItalicFont(for: .body)
        title.translatesAutoresizingMaskIntoConstraints = false
        title.numberOfLines = 3
        title.lineBreakMode = .byCharWrapping
        return title
    }()

    private lazy var fileSubtitle: UILabel = {
        let subtitle = UILabel()
        subtitle.font = UIFont.preferredItalicFont(for: .caption2)
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.numberOfLines = 1
        return subtitle
    }()

    lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentHuggingPriority(.defaultLow, for: .vertical)
        return label
    }()

    override func setupSubviews() {
        super.setupSubviews()
        let spacerView = UIView()
        spacer = spacerView.constraintHeightTo(8, priority: .defaultHigh)
        spacer?.isActive = true
        mainContentView.addArrangedSubview(fileStackView)
        mainContentView.addArrangedSubview(spacerView)
        mainContentView.addArrangedSubview(messageLabel)
        imageWidthConstraint = fileImageView.constraintWidthTo(50)
        imageHeightConstraint = fileImageView.constraintHeightTo(50 * 1.3, priority: .defaultLow)
        horizontalLayout = true
    }

    override func prepareForReuse() {
        messageLabel.text = nil
        messageLabel.attributedText = nil
        fileImageView.image = nil
    }

    override func update(msg: DcMsg, messageStyle: UIRectCorner, isAvatarVisible: Bool) {
        if let text = msg.text, !text.isEmpty {
            messageLabel.text = text
            spacer?.isActive = true
        } else {
            spacer?.isActive = false
        }
        if let url = msg.fileURL {
            generateThumbnailFor(url: url, placeholder: defaultImage)
        } else {
            fileImageView.image = defaultImage
            horizontalLayout = true
        }
        fileTitle.text = msg.filename
        fileSubtitle.text = msg.getPrettyFileSize()
        super.update(msg: msg, messageStyle: messageStyle, isAvatarVisible: isAvatarVisible)
    }

    private func generateThumbnailFor(url: URL, placeholder: UIImage?) {
        if let thumbnail = ThumbnailCache.shared.restoreImage(key: url.absoluteString) {
            fileImageView.image = thumbnail
            horizontalLayout = false
        } else if let pdfThumbnail = DcUtils.thumbnailFromPdf(withUrl: url) {
            fileImageView.image = pdfThumbnail
            horizontalLayout = false
            ThumbnailCache.shared.storeImage(image: pdfThumbnail, key: url.absoluteString)
        } else {
            let controller = UIDocumentInteractionController(url: url)
            fileImageView.image = controller.icons.first ?? placeholder
            horizontalLayout = true
        }
    }
    
}

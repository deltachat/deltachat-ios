import UIKit
import DcCore

class FileTableViewCell: UITableViewCell {

    static let reuseIdentifier = "file_table_view_cell"

    private let fileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [title, subtitle])
        stackView.axis = NSLayoutConstraint.Axis.vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.clipsToBounds = true
        return stackView
    }()

    private lazy var title: UILabel = {
        let title = UILabel()
        title.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        title.translatesAutoresizingMaskIntoConstraints = false
        return title
    }()

    private lazy var subtitle: UILabel = {
        let subtitle = UILabel()
        subtitle.font = UIFont.italicSystemFont(ofSize: 12)
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        return subtitle
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        fileImageView.image = nil
        title.text = nil
        subtitle.text = nil
    }

    // MARK: - layout
    private func setupSubviews() {
        contentView.addSubview(fileImageView)
        contentView.addSubview(stackView)
        fileImageView.translatesAutoresizingMaskIntoConstraints = false
        fileImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0).isActive = true
        fileImageView.heightAnchor.constraint(lessThanOrEqualTo: contentView.heightAnchor, multiplier: 0.9).isActive = true
        fileImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 0).isActive = true
        fileImageView.widthAnchor.constraint(equalToConstant: 50).isActive = true
        stackView.constraintToTrailingOf(fileImageView, paddingLeading: 12).isActive = true
        stackView.constraintAlignTrailingTo(contentView, paddingTrailing: 12).isActive = true
        stackView.constraintAlignTopTo(contentView, paddingTop: 12).isActive = true
        stackView.constraintAlignBottomTo(contentView, paddingBottom: 12).isActive = true

    }

    // MARK: - update
    func update(msg: DcMsg) {
       /* switch msg.kind {
        case .fileText(let mediaItem):
            if let url = mediaItem.url {
                generateThumbnailFor(url: url, placeholder: mediaItem.placeholderImage)
            } else {
                fileImageView.image = mediaItem.placeholderImage
            }
        default:
            guard let url = msg.fileURL else {
                return
            }
            generateThumbnailFor(url: url, placeholder: nil)
        }*/
        title.text = msg.filename
        subtitle.text = msg.getPrettyFileSize()
    }

    private func generateThumbnailFor(url: URL, placeholder: UIImage?) {
        if let thumbnail = ThumbnailCache.shared.restoreImage(key: url.absoluteString) {
            fileImageView.image = thumbnail
        } else if let pdfThumbnail = DcUtils.thumbnailFromPdf(withUrl: url) {
            fileImageView.image = pdfThumbnail
            ThumbnailCache.shared.storeImage(image: pdfThumbnail, key: url.absoluteString)
        } else {
            let controller = UIDocumentInteractionController(url: url)
            fileImageView.image = controller.icons.first ?? placeholder
        }

    }
}

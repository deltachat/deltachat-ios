import UIKit
import DcCore

class DocumentGalleryFileCell: UITableViewCell {

    static let reuseIdentifier = "document_gallery_file_cell"

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
        if let fileUrl = msg.fileURL {
            generateThumbnailFor(url: fileUrl, placeholder: UIImage(named: "ic_attach_file_36pt")?.maskWithColor(color: DcColors.grayTextColor))
        }
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

    // needed for iOS 12 context men
    @objc func itemDelete(_ sender: Any) {
        self.performAction(#selector(DocumentGalleryFileCell.itemDelete(_:)), with: sender)
    }

    @objc func showInChat(_ sender: Any) {
        self.performAction(#selector(DocumentGalleryFileCell.showInChat(_:)), with: sender)
    }

    func performAction(_ action: Selector, with sender: Any?) {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            tableView.delegate?.tableView?(
                tableView,
                performAction: action,
                forRowAt: indexPath,
                withSender: sender
            )
        }
    }
}

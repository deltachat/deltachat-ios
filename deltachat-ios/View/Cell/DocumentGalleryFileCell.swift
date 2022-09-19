import UIKit
import DcCore

class DocumentGalleryFileCell: UITableViewCell {

    static let reuseIdentifier = "document_gallery_file_cell"

    static var cellHeight: CGFloat {
        let textHeight = UIFont.preferredFont(forTextStyle: .headline).pointSize + UIFont.preferredFont(forTextStyle: .subheadline).pointSize + 24
        if textHeight > 60 {
            return textHeight
        }
        return 60
    }

    private let fileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [title, subtitle])
        stackView.axis = NSLayoutConstraint.Axis.vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.distribution = .fillProportionally
        stackView.contentMode = .center
        return stackView
    }()

    private lazy var title: UILabel = {
        let title = UILabel()
        title.font = UIFont.preferredFont(forTextStyle: .headline)
        title.translatesAutoresizingMaskIntoConstraints = false
        return title
    }()

    private lazy var subtitle: UILabel = {
        let subtitle = UILabel()
        subtitle.font = UIFont.preferredItalicFont(for: .subheadline)
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
        stackView.constraintAlignTopTo(contentView, paddingTop: 6).isActive = true
        stackView.constraintAlignBottomTo(contentView, paddingBottom: 6).isActive = true

    }

    // MARK: - update
    func update(msg: DcMsg) {
        if msg.type == DC_MSG_WEBXDC {
            updateWebxdcMsg(msg: msg)
        } else {
            updateFileMsg(msg: msg)
        }
    }

    private func updateFileMsg(msg: DcMsg) {
        if let fileUrl = msg.fileURL {
            generateThumbnailFor(url: fileUrl, placeholder: UIImage(named: "ic_attach_file_36pt")?.maskWithColor(color: DcColors.grayTextColor))
        }
        title.text = msg.filename
        subtitle.text = msg.getPrettyFileSize()
    }

    private func updateWebxdcMsg(msg: DcMsg) {
        let dict = msg.getWebxdcInfoDict()
        if let iconfilePath = dict["icon"] as? String {
            let blob = msg.getWebxdcBlob(filename: iconfilePath)
            if !blob.isEmpty {
                fileImageView.image = UIImage(data: blob)?.sd_resizedImage(with: CGSize(width: 50, height: 50), scaleMode: .aspectFill)
            }
        }

        let document = dict["document"] as? String ?? ""
        let summary = dict["summary"] as? String ?? ""
        let name = dict["name"] as? String ?? "ErrName" // name should not be empty

        title.text = document.isEmpty ? name : "\(document) – \(name)"
        subtitle.text = summary.isEmpty ? String.localized("webxdc_app") : summary
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

    // needed for iOS 12 context menu
    @objc func itemDelete(_ sender: Any) {
        self.performAction(#selector(DocumentGalleryFileCell.itemDelete(_:)), with: sender)
    }

    @objc func showInChat(_ sender: Any) {
        self.performAction(#selector(DocumentGalleryFileCell.showInChat(_:)), with: sender)
    }

    @objc func share(_ sender: Any) {
        self.performAction(#selector(DocumentGalleryFileCell.share(_:)), with: sender)
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

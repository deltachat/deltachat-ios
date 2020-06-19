import UIKit
import DcCore

class FileTableViewCell: UITableViewCell {

    static let reuseIdentifier = "file_table_view_cell"

    private let fileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        fileImageView.image = nil
        detailTextLabel?.text = nil
        textLabel?.text = nil
    }

    // MARK: - layout
    private func setupSubviews() {
        guard let textLabel = textLabel, let detailTextLabel = detailTextLabel else { return }

        contentView.addSubview(fileImageView)
        fileImageView.translatesAutoresizingMaskIntoConstraints = false
        fileImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0).isActive = true
        fileImageView.heightAnchor.constraint(lessThanOrEqualTo: contentView.heightAnchor, multiplier: 0.9).isActive = true
        fileImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 0).isActive = true
        fileImageView.widthAnchor.constraint(equalToConstant: 50).isActive = true
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        detailTextLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.leadingAnchor.constraint(equalTo: fileImageView.trailingAnchor, constant: 10).isActive = true
        textLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 0).isActive = true
        textLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor, constant: 0).isActive = true
        detailTextLabel.leadingAnchor.constraint(equalTo: textLabel.leadingAnchor, constant: 0).isActive = true
        detailTextLabel.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 0).isActive = true
        detailTextLabel.trailingAnchor.constraint(equalTo: textLabel.trailingAnchor, constant: 0).isActive = true
        detailTextLabel.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: 0).isActive = true
    }

    // MARK: - update
    func update(msg: DcMsg) {
        switch msg.kind {
        case .fileText(let mediaItem):
            if let url = mediaItem.url {
                if let pdfThumbnail = DcUtils.thumbnailFromPdf(withUrl: url) {
                    fileImageView.image = pdfThumbnail
                } else {
                    let controller = UIDocumentInteractionController(url: url)
                    fileImageView.image = controller.icons.first ?? mediaItem.placeholderImage
                }
            } else {
                fileImageView.image = mediaItem.placeholderImage
            }
            textLabel?.text = msg.filename
            detailTextLabel?.attributedText = mediaItem.text?[MediaItemConstants.mediaSubtitle]
        default:
            break
        }
    }
}

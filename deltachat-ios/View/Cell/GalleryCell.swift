import UIKit
import DcCore
import SDWebImage


class GalleryCell: UICollectionViewCell {
    static let reuseIdentifier = "gallery_cell"

    var bgColor: UIColor = DcColors.defaultBackgroundColor

    var imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = .clear
        return view
    }()

    private lazy var playButtonView: PlayButtonView = {
        let playButtonView = PlayButtonView()
        playButtonView.isHidden = true
        return playButtonView
    }()


    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        // reset to defaults
        imageView.contentMode = .scaleAspectFill
    }

    private func setupSubviews() {
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4).isActive = true
        imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4).isActive = true
        imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4).isActive = true
        imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4).isActive = true

        contentView.addSubview(playButtonView)
        playButtonView.translatesAutoresizingMaskIntoConstraints = false
        playButtonView.centerInSuperview()
        playButtonView.constraint(equalTo: CGSize(width: 50, height: 50))
    }

    func update(msg: DcMsg) {
        guard let viewtype = msg.viewtype, let fileUrl = msg.fileURL else {
            return
        }

        switch viewtype {
        case .image:
            imageView.image = msg.image
            playButtonView.isHidden = true
        case .video:
            imageView.image = DcUtils.generateThumbnailFromVideo(url: fileUrl)
            playButtonView.isHidden = false
        case .gif:
            imageView.sd_setImage(with: fileUrl, placeholderImage: nil)
            playButtonView.isHidden = true
        case .file:
            var thumbnail: UIImage?
            if let pdfThumbnail =  DcUtils.thumbnailFromPdf(withUrl: fileUrl, pageNumber: 1) { // DcUtils.generateThumbnailFromPDF(of: contentView.frame.size, for: fileUrl, atPage: 0) {
                thumbnail = pdfThumbnail
            } else {
                let controller = UIDocumentInteractionController(url: fileUrl)
                thumbnail = controller.icons.last
            }
            imageView.image = thumbnail
            imageView.contentMode = .scaleAspectFit
            contentView.backgroundColor = .lightGray
        default:
            safe_fatalError("unsupported viewtype - viewtype \(viewtype) not supported.")
        }
    }

    override var isSelected: Bool {
        willSet {
            // to provide visual feedback on select events
            contentView.backgroundColor = newValue ? DcColors.primary : bgColor
            imageView.alpha = newValue ? 0.75 : 1.0
        }
    }
}

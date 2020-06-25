import UIKit
import DcCore
import SDWebImage


class GalleryCell: UICollectionViewCell {
    static let reuseIdentifier = "gallery_cell"

    var imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
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

    private func setupSubviews() {
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0).isActive = true
        imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0).isActive = true
        imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0).isActive = true
        imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0).isActive = true

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
            let key = fileUrl.absoluteString
            if let image = ThumbnailCache.shared.restoreImage(key: key) {
                imageView.image = image
            } else {
                imageView.loadVideoThumbnail(from: fileUrl, placeholderImage: nil) { thumbnail in
                    if let image = thumbnail {
                        ThumbnailCache.shared.storeImage(image: image, key: key)
                    }
                }
            }
            playButtonView.isHidden = false
        case .gif:
            imageView.sd_setImage(with: fileUrl, placeholderImage: nil)
            playButtonView.isHidden = true
        default:
            safe_fatalError("unsupported viewtype - viewtype \(viewtype) not supported.")
        }
    }

    override var isSelected: Bool {
        willSet {
            // to provide visual feedback on select events
            contentView.backgroundColor = newValue ? DcColors.primary : .white
            imageView.alpha = newValue ? 0.75 : 1.0
        }
    }
}

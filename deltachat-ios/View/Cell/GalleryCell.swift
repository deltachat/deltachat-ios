import UIKit
import DcCore
import SDWebImage

class GalleryCell: UICollectionViewCell {
    static let reuseIdentifier = "gallery_cell"

    weak var item: GalleryItem?

    var imageView: SDAnimatedImageView = {
        let view = SDAnimatedImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = DcColors.defaultBackgroundColor
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
        super.prepareForReuse()
        item?.onImageLoaded = nil
        item = nil
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

    func update(item: GalleryItem) {
        self.item = item
        item.onImageLoaded = { [weak self] image in
            self?.imageView.image = image
        }
        playButtonView.isHidden = item.msg.type != DC_MSG_VIDEO
        imageView.image = item.thumbnailImage

        contentView.isAccessibilityElement = true
        contentView.accessibilityHint = String.localized(playButtonView.isHidden ? "image" : "video")
            + ", " + DateUtils.getBriefRelativeTimeSpanString(timeStamp: Double(item.msg.timestamp))
    }

    override var isSelected: Bool {
        willSet {
            // to provide visual feedback on select events
            contentView.backgroundColor = newValue ? DcColors.primary : .white
            imageView.alpha = newValue ? 0.75 : 1.0
        }
    }
}

import UIKit
import DcCore
import SDWebImage

class WebxdcGridCell: UICollectionViewCell {
    static let reuseIdentifier = "webxdc_cell"

    weak var item: GalleryItem?

    private lazy var imageView: SDAnimatedImageView = {
        let view = SDAnimatedImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.isAccessibilityElement = false
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        return view
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(for: .caption1, weight: .light)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = DcColors.defaultInverseColor
        label.backgroundColor = DcColors.defaultTransparentBackgroundColor
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = DcColors.defaultBackgroundColor
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        item?.onImageLoaded = nil
        item = nil
        imageView.image = nil
        descriptionLabel.text = nil
    }

    private func setupSubviews() {
        contentView.addSubview(imageView)
        imageView.addSubview(descriptionLabel)
        addConstraints([
            imageView.constraintAlignLeadingToAnchor(contentView.leadingAnchor),
            imageView.constraintAlignTrailingToAnchor(contentView.trailingAnchor),
            imageView.constraintAlignTopToAnchor(contentView.topAnchor),
            imageView.constraintAlignBottomToAnchor(contentView.bottomAnchor),
            descriptionLabel.constraintAlignLeadingTo(imageView),
            descriptionLabel.constraintAlignTrailingMaxTo(imageView),
            descriptionLabel.constraintAlignBottomTo(imageView),
        ])
    }

    func update(item: GalleryItem) {
        self.item = item
        item.onImageLoaded = { [weak self] image in
            self?.imageView.image = image
        }
        imageView.image = item.thumbnailImage
        descriptionLabel.text = item.description
    }

    override var isSelected: Bool {
        willSet {
            // to provide visual feedback on select events
            contentView.backgroundColor = newValue ? DcColors.primary : DcColors.defaultBackgroundColor
            imageView.alpha = newValue ? 0.75 : 1.0
        }
    }
}
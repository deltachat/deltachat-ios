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
        return view
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(for: .caption1, weight: .light)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = DcColors.defaultInverseColor
        label.backgroundColor = DcColors.defaultBackgroundColor
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
        contentView.addSubview(descriptionLabel)
        addConstraints([
            imageView.constraintAlignLeadingToAnchor(contentView.leadingAnchor),
            imageView.constraintAlignTrailingToAnchor(contentView.trailingAnchor),
            imageView.constraintAlignTopToAnchor( contentView.topAnchor),
            descriptionLabel.constraintAlignLeadingTo(imageView),
            descriptionLabel.constraintToBottomOf(imageView),
            descriptionLabel.constraintAlignTrailingTo(imageView),
            descriptionLabel.constraintAlignBottomToAnchor(contentView.bottomAnchor),
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
            contentView.backgroundColor = newValue ? DcColors.primary : .white
            imageView.alpha = newValue ? 0.75 : 1.0
        }
    }
}

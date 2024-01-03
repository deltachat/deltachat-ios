import UIKit
import DcCore
import SDWebImage

class WebxdcGridCell: UICollectionViewCell {
    static let reuseIdentifier = "webxdc_cell"

    weak var item: GalleryItem?

    private var font: UIFont {
        let regularFont = UIFont.preferredFont(forTextStyle: .subheadline)
        if regularFont.pointSize > 28 {
            return UIFont.systemFont(ofSize: 28)
        }
        return regularFont
    }

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
        label.font = font
        label.lineBreakMode = .byTruncatingTail
        label.textColor = DcColors.defaultInverseColor
        label.backgroundColor = DcColors.defaultTransparentBackgroundColor
        label.textAlignment = .center
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
            imageView.constraintAlignTopToAnchor(contentView.topAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            descriptionLabel.constraintAlignTrailingMaxTo(contentView),
            descriptionLabel.constraintCenterXTo(contentView),
            descriptionLabel.widthAnchor.constraint(lessThanOrEqualTo: imageView.widthAnchor),
            descriptionLabel.constraintToBottomOf(imageView, paddingTop: 4),
            descriptionLabel.constraintAlignBottomMaxTo(contentView)
        ])
    }

    func update(item: GalleryItem) {
        self.item = item
        item.onImageLoaded = { [weak self] image in
            self?.imageView.image = image
        }
        imageView.image = item.thumbnailImage
        descriptionLabel.text = item.msg.getWebxdcInfoDict()["name"] as? String ?? "ErrName"
    }

    override var isSelected: Bool {
        willSet {
            // to provide visual feedback on select events
            imageView.alpha = newValue ? 0.75 : 1.0
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory {
                descriptionLabel.font = font
        }
    }
}

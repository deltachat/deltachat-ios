import UIKit
import DcCore
import SDWebImage

class RecentWebxdcAppsCell: UICollectionViewCell {
    static let reuseIdentifier = "RecentWebxdcAppsCell"

    weak var item: GalleryItem?

    private var font: UIFont {
        let regularFont = UIFont.preferredFont(forTextStyle: .subheadline)
        if regularFont.pointSize > 28 {
            return UIFont.systemFont(ofSize: 28)
        }
        return regularFont
    }

    private let contentStackView: UIStackView
    private let imageView: SDAnimatedImageView
    private let descriptionLabel: UILabel

    override init(frame: CGRect) {
        imageView = SDAnimatedImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isAccessibilityElement = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = 6

        descriptionLabel = UILabel()
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.lineBreakMode = .byTruncatingTail
        descriptionLabel.textColor = DcColors.defaultInverseColor
        descriptionLabel.backgroundColor = DcColors.defaultTransparentBackgroundColor
        descriptionLabel.textAlignment = .center

        contentStackView = UIStackView(arrangedSubviews: [imageView, descriptionLabel])
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.spacing = 4
        contentStackView.axis = .vertical
        contentStackView.alignment = .center

        super.init(frame: frame)
        contentView.addSubview(contentStackView)
        backgroundColor = DcColors.defaultBackgroundColor
        descriptionLabel.font = font

        setupConstraints()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        item?.onImageLoaded = nil
        item = nil
        imageView.image = nil
        descriptionLabel.text = nil
    }

    private func setupConstraints() {
        let constraints = [
            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            descriptionLabel.widthAnchor.constraint(lessThanOrEqualTo: imageView.widthAnchor),
        ]

        NSLayoutConstraint.activate(constraints)

//            imageView.constraintAlignLeadingToAnchor(contentView.leadingAnchor),
//            imageView.constraintAlignTrailingToAnchor(contentView.trailingAnchor),
//            imageView.constraintAlignTopToAnchor(contentView.topAnchor),
//            ,
//            descriptionLabel.constraintAlignTrailingMaxTo(contentView),
//            descriptionLabel.constraintCenterXTo(contentView),
//            ,
//            descriptionLabel.constraintToBottomOf(imageView, paddingTop: 4),
//            descriptionLabel.constraintToBottomOf(contentView)
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

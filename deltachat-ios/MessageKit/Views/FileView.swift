import UIKit
import DcCore

class FileView: UIView {

    static let badgeSize: CGFloat = 54
    static let defaultHeight: CGFloat = 78
    static let defaultWidth: CGFloat = 250

    private lazy var previewImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        return imageView
    }()

    private lazy var titleView: MessageLabel = {
        let label = MessageLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var subtitleView: MessageLabel = {
        let label = MessageLabel()
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = false
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var fileBadgeView: InitialsBadge = {
        let defaultImage = UIImage(named: "ic_attach_file_36pt") ?? UIImage()
        let badge: InitialsBadge = InitialsBadge(image: defaultImage, size: FileView.badgeSize)
        badge.setColor(DcColors.middleGray)
        badge.isAccessibilityElement = false
        badge.isHidden = false
        return badge
    }()

    private lazy var verticalStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleView, subtitleView])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: FileMessageCell.insetHorizontalSmall,
                                                                     leading: FileMessageCell.insetHorizontalSmall,
                                                                     bottom: FileMessageCell.insetHorizontalSmall,
                                                                     trailing: FileMessageCell.insetHorizontalSmall)
        return stackView
    }()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(fileBadgeView)
        addSubview(verticalStackView)
    }

    func configureFor(mediaItem: MediaItem) {
        removeConstraints(self.constraints)
        previewImageView.removeFromSuperview()
        if let previewImage = mediaItem.image {
            previewImageView.image = previewImage
            addSubview(previewImageView)
            addConstraints([
                previewImageView.constraintAlignTopTo(self),
                previewImageView.constraintAlignLeadingTo(self),
                previewImageView.constraintAlignTrailingTo(self),
            ])
        } else {
            addConstraints([
                fileBadgeView.constraintAlignLeadingTo(self),
                fileBadgeView.constraintWidthTo(FileView.badgeSize),
                fileBadgeView.constraintHeightTo(FileView.badgeSize),
                fileBadgeView.constraintCenterYTo(self)
            ])
            addConstraints([
                verticalStackView.constraintCenterYTo(self),
                verticalStackView.constraintToTrailingOf(fileBadgeView),
                verticalStackView.constraintAlignTrailingTo(self)
            ])
        }
        if let title = mediaItem.text?[MediaItemConstants.mediaTitle] {
            titleView.attributedText = title
        }
        if let subtitle = mediaItem.text?[MediaItemConstants.mediaSubtitle] {
            subtitleView.attributedText = subtitle
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func prepareForReuse() {
        titleView.attributedText = nil
        subtitleView.attributedText = nil
        previewImageView.image = nil
    }
}

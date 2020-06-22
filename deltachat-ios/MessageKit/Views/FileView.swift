import UIKit
import DcCore

class FileView: UIView {

    static let badgeSize: CGFloat = 48
    static let defaultHeight: CGFloat = 78
    static let defaultWidth: CGFloat = 250

    private lazy var titleView: MessageLabel = {
        let label = MessageLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 3
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

    private lazy var fileThumbnail: UIImageView = {
        let image = UIImageView()
        image.frame.size = CGSize(width: FileView.badgeSize, height: FileView.badgeSize)
        image.contentMode = .scaleAspectFill
        image.translatesAutoresizingMaskIntoConstraints = false
        image.isAccessibilityElement = false
        return image
    }()

    private lazy var verticalStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleView, subtitleView])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()

    init(directionalLayoutMargins: NSDirectionalEdgeInsets) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        verticalStackView.directionalLayoutMargins = directionalLayoutMargins
        addSubview(fileThumbnail)
        addSubview(verticalStackView)
        addConstraints([
            fileThumbnail.constraintAlignLeadingTo(self),
            fileThumbnail.constraintWidthTo(FileView.badgeSize),
            fileThumbnail.constraintHeightTo(FileView.badgeSize),
            fileThumbnail.constraintCenterYTo(self),
        ])
        addConstraints([
            verticalStackView.constraintCenterYTo(self),
            verticalStackView.constraintToTrailingOf(fileThumbnail),
            verticalStackView.constraintAlignTrailingTo(self)
        ])
    }

    func configureFor(mediaItem: MediaItem) {
        if let url = mediaItem.url {
            let controller = UIDocumentInteractionController(url: url)
            fileThumbnail.image = controller.icons.first ?? mediaItem.placeholderImage
        } else {
            fileThumbnail.image = mediaItem.placeholderImage
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
        fileThumbnail.image = nil
    }
}

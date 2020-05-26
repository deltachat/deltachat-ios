import UIKit
import DcCore

class FileView: UIView {

    static let badgeSize: CGFloat = 54
    static let defaultHeight: CGFloat = 78
    static let defaultWidth: CGFloat = 250

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
        let badge: InitialsBadge = InitialsBadge(image: UIImage(), size: FileView.badgeSize)
        badge.isAccessibilityElement = false
        badge.isHidden = false
        badge.cornerRadius = 6
        return badge
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
        addSubview(fileBadgeView)
        addSubview(verticalStackView)
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

    func configureFor(mediaItem: MediaItem) {
        if let url = mediaItem.url {
            let controller = UIDocumentInteractionController(url: url)
            fileBadgeView.setImage(controller.icons.first ?? mediaItem.placeholderImage)
        } else {
            fileBadgeView.setImage(mediaItem.placeholderImage)
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
        fileBadgeView.reset()
    }
}

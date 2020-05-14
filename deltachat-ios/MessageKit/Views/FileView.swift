import UIKit
import DcCore

class FileView: UIView {

    static let badgeSize: CGFloat = 54
    let defaultHeight: CGFloat = 100
    let defaultWidth: CGFloat = 250

    private lazy var previewImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var titleView: MessageLabel = {
        let label = MessageLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var subtitleView: MessageLabel = {
        let label = MessageLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var fileBadgeView: InitialsBadge = {
        let defaultImage = UIImage(named: "ic_attach_file_36pt") ?? UIImage()
        let badge: InitialsBadge = InitialsBadge(image: defaultImage, size: FileView.badgeSize)
        badge.setColor(DcColors.middleGray)
        badge.isAccessibilityElement = false
        return badge
    }()

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleView, subtitleView])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .leading
        return stackView
    }()

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight))
        translatesAutoresizingMaskIntoConstraints = false
    }

    func configureFor(mediaItem: MediaItem) {
        removeConstraints(self.constraints)
        previewImageView.removeFromSuperview()
        //titleView.removeFromSuperview()
        //subtitleView.removeFromSuperview()
        fileBadgeView.removeFromSuperview()
        setupSubviews(mediaItem: mediaItem)
    }

    private func setupSubviews(mediaItem: MediaItem) {
        if let previewImage = mediaItem.image {
            previewImageView.image = previewImage
            addSubview(previewImageView)
            addSubview(stackView)
            //addSubview(titleView)
            //addSubview(subtitleView)
            addConstraints([
                previewImageView.constraintAlignTopTo(self),
                previewImageView.constraintAlignLeadingTo(self),
                previewImageView.constraintAlignTrailingTo(self),
                /*titleView.constraintAlignTopTo(previewImageView),
                titleView.constraintAlignLeadingTo(self),
                titleView.constraintAlignTrailingTo(self),
                subtitleView.constraintAlignLeadingTo(self),
                subtitleView.constraintAlignTrailingTo(self),
                subtitleView.constraintAlignTopTo(titleView)*/
            ])
        } else {
            fileBadgeView.setImage(mediaItem.placeholderImage)


            addSubview(fileBadgeView)
            addConstraints([
                fileBadgeView.constraintAlignLeadingTo(self, paddingLeading: FileMessageCell.insetHorizontalSmall),
                fileBadgeView.constraintWidthTo(FileView.badgeSize),
                fileBadgeView.constraintHeightTo(FileView.badgeSize),
                fileBadgeView.constraintCenterYTo(self)
            ])
            addSubview(stackView)
            addConstraints([
                stackView.constraintCenterYTo(self),
                stackView.constraintToTrailingOf(fileBadgeView, paddingLeading: FileMessageCell.insetHorizontalSmall),
                stackView.constraintAlignTrailingTo(self, paddingTrailing: FileMessageCell.insetHorizontalSmall)
            ])
            /*addSubview(titleView)
            addConstraints([
                titleView.constraintAlignTopTo(self, paddingTop: FileMessageCell.insetTop),
                titleView.constraintToTrailingOf(fileBadgeView, paddingLeading: FileMessageCell.insetHorizontalSmall),
                titleView.constraintAlignTrailingTo(self, paddingTrailing: FileMessageCell.insetHorizontalSmall),
            ])
            addSubview(subtitleView)
            addConstraints([
                subtitleView.constraintToTrailingOf(fileBadgeView, paddingLeading: FileMessageCell.insetHorizontalSmall),
                subtitleView.constraintAlignTrailingTo(self, paddingTrailing: FileMessageCell.insetHorizontalSmall),
                subtitleView.constraintToBottomOf(titleView)
            ])*/
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

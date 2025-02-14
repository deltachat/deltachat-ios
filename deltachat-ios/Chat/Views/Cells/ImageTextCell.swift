import Foundation
import UIKit
import DcCore
import SDWebImage

class ImageTextCell: BaseMessageCell, ReusableCell {

    static let reuseIdentifier = "ImageTextCell"

    let minImageWidth: CGFloat = 125
    var imageHeightConstraint: NSLayoutConstraint?
    var imageWidthConstraint: NSLayoutConstraint?

    lazy var contentImageView: SDAnimatedImageView = {
        let imageView = SDAnimatedImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        imageView.isUserInteractionEnabled = true
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    var contentImageIsPlaceholder: Bool = true

    /// The play button view to display on video messages.
    open lazy var playButtonView: PlayButtonView = {
        let playButtonView = PlayButtonView()
        playButtonView.isHidden = true
        playButtonView.translatesAutoresizingMaskIntoConstraints = false
        return playButtonView
    }()

    override func setupSubviews() {
        super.setupSubviews()
        contentImageView.addSubview(playButtonView)
        playButtonView.centerInSuperview()
        playButtonView.constraint(equalTo: CGSize(width: 50, height: 50))
        mainContentView.addArrangedSubview(contentImageView)
        mainContentView.addArrangedSubview(messageLabel)
        messageLabel.paddingLeading = 12
        messageLabel.paddingTrailing = 12
        contentImageView.constraintAlignLeadingMaxTo(mainContentView, priority: .required).isActive = true
        contentImageView.constraintAlignTrailingMaxTo(mainContentView, priority: .required).isActive = true
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onImageTapped))
        gestureRecognizer.numberOfTapsRequired = 1
        contentImageView.addGestureRecognizer(gestureRecognizer)
    }

    override func update(dcContext: DcContext, msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, searchText: String? = nil, highlight: Bool) {
        messageLabel.text = msg.text
        let hasEmptyText = msg.text?.isEmpty ?? true
        bottomCompactView = msg.type != DC_MSG_STICKER && !msg.hasHtml && hasEmptyText
        showBottomLabelBackground = !msg.hasHtml && hasEmptyText
        mainContentView.spacing = msg.text?.isEmpty ?? false ? 0 : 6
        topCompactView = msg.quoteText == nil ? true : false
        isTransparent = (msg.type == DC_MSG_STICKER && msg.quoteMessage == nil)
        topLabel.isHidden = msg.type == DC_MSG_STICKER
        contentImageIsPlaceholder = true
        tag = msg.id

        if let url = msg.fileURL,
            msg.type == DC_MSG_IMAGE || msg.type == DC_MSG_GIF || msg.type == DC_MSG_STICKER {
            contentImageView.sd_setImage(with: url,
                                         placeholderImage: UIImage(color: UIColor.init(alpha: 0,
                                                                                       red: 255,
                                                                                       green: 255,
                                                                                       blue: 255),
                                                                   size: CGSize(width: 500, height: 500)))
            contentImageIsPlaceholder = false
            playButtonView.isHidden = true
            a11yDcType = msg.type == DC_MSG_GIF ? String.localized("gif") : String.localized("image")
            setAspectRatioFor(message: msg)
        } else if msg.type == DC_MSG_VIDEO, let url = msg.fileURL {
            playButtonView.isHidden = false
            a11yDcType = String.localized("video")
            let placeholderImage = UIImage(color: UIColor.init(alpha: 0, red: 255, green: 255, blue: 255), size: CGSize(width: 250, height: 250))
            contentImageView.image = placeholderImage
            DispatchQueue.global(qos: .userInteractive).async {
                let thumbnailImage = DcUtils.generateThumbnailFromVideo(url: url)
                if let thumbnailImage = thumbnailImage {
                    DispatchQueue.main.async { [weak self] in
                        if msg.id == self?.tag {
                            self?.contentImageView.image = thumbnailImage
                            self?.contentImageIsPlaceholder = false
                        }
                    }
                }
            }
            setAspectRatioFor(message: msg, with: placeholderImage, isPlaceholder: true)
        }
        super.update(dcContext: dcContext,
                     msg: msg,
                     messageStyle: messageStyle,
                     showAvatar: showAvatar,
                     showName: showName,
                     searchText: searchText,
                     highlight: highlight)
    }

    @objc func onImageTapped() {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            baseDelegate?.imageTapped(indexPath: indexPath, previewError: contentImageIsPlaceholder)
        }
    }

    private func setStickerAspectRatio(width: CGFloat, height: CGFloat) {
        if height == 0 || width == 0 {
            return
        }
        var width = width
        var height = height

        self.imageHeightConstraint?.isActive = false
        self.imageWidthConstraint?.isActive = false
        self.contentImageView.contentMode = .scaleAspectFit

        // check if sticker has the allowed minimal width
        if width < minImageWidth {
            height = (height / width) * minImageWidth
            width = minImageWidth
        }

        // check if sticker has the allowed maximal width
        let maxWidth  = min(UIScreen.main.bounds.height, UIScreen.main.bounds.width) / 2
        if width > maxWidth {
            height = (height / width) * maxWidth
            width = maxWidth
        }

        self.imageWidthConstraint = self.contentImageView.widthAnchor.constraint(lessThanOrEqualToConstant: width)
        self.imageHeightConstraint = self.contentImageView.heightAnchor.constraint(
            lessThanOrEqualTo: self.contentImageView.widthAnchor,
            multiplier: height / width
        )

        self.imageHeightConstraint?.isActive = true
        self.imageWidthConstraint?.isActive = true
    }

    private func setAspectRatio(width: CGFloat, height: CGFloat) {
        guard let orientation = UIApplication.shared.orientation else { return }

        if height == 0 || width == 0 {
            return
        }
        var width = width
        var height = height

        self.imageHeightConstraint?.isActive = false
        self.imageWidthConstraint?.isActive = false
        var scaleType = ContentMode.scaleAspectFill

        // check if image has the allowed minimal width
        if width < minImageWidth {
            height = (height / width) * minImageWidth
            width = minImageWidth
        }
        
        // in some cases we show images in square sizes
        // restrict width to half of the screen in device landscape and to 5 / 6 in portrait
        // it results in a good balance between message text width and image size
        let factor: CGFloat = orientation.isLandscape ? 1 / 2 : 5 / 6
        var squareSize  = UIScreen.main.bounds.width * factor
        
        if  height > width {
            // show square image for portrait images
            // reduce the image square size if there's no message text so that it fits best in the viewable area
            if squareSize > UIScreen.main.bounds.height * 5 / 8 && (messageLabel.text?.isEmpty ?? true) {
                squareSize = UIScreen.main.bounds.height * 5 / 8
            }
            imageHeightConstraint = self.contentImageView.heightAnchor.constraint(lessThanOrEqualToConstant: squareSize)
            imageWidthConstraint = self.contentImageView.widthAnchor.constraint(lessThanOrEqualToConstant: squareSize)
        } else {
            // show image in aspect ratio for landscape images
            if orientation.isLandscape && height > UIScreen.main.bounds.height * 5 / 8 {
                // shrink landscape image in landscape device orientation if image height is too big
                self.imageHeightConstraint = self.contentImageView.heightAnchor.constraint(lessThanOrEqualToConstant: UIScreen.main.bounds.height * 5 / 8)
                self.imageWidthConstraint = self.contentImageView.widthAnchor.constraint(lessThanOrEqualTo: self.contentImageView.heightAnchor,
                                                                                         multiplier: width/height)
            } else {
                if width < squareSize {
                    // very small width images should be forced to not be scaled down further
                    self.imageWidthConstraint = self.contentImageView.widthAnchor.constraint(greaterThanOrEqualToConstant: width)
                    self.imageHeightConstraint = self.contentImageView.heightAnchor.constraint(equalToConstant: height)
                    scaleType = ContentMode.scaleAspectFit
                } else {
                    // large width images might scale down until the max allowed text width
                    self.imageWidthConstraint = self.contentImageView.widthAnchor.constraint(lessThanOrEqualToConstant: width)
                    self.imageHeightConstraint = self.contentImageView.heightAnchor.constraint(
                        lessThanOrEqualTo: self.contentImageView.widthAnchor,
                        multiplier: height / width
                    )
                }
            }
        }
        self.contentImageView.contentMode = scaleType
        self.imageHeightConstraint?.isActive = true
        self.imageWidthConstraint?.isActive = true
    }

    private func setAspectRatioFor(message: DcMsg) {
        var width = message.messageWidth
        var height = message.messageHeight
        if width == 0 || height == 0,
           let image = message.image {
            width = image.size.width
            height = image.size.height
            message.setLateFilingMediaSize(width: width, height: height, duration: 0)
        }
        if message.type == DC_MSG_STICKER {
            setStickerAspectRatio(width: width, height: height)
        } else {
            setAspectRatio(width: width, height: height)
        }
    }


    private func setAspectRatioFor(message: DcMsg, with image: UIImage?, isPlaceholder: Bool) {
        var width = message.messageWidth
        var height = message.messageHeight
        if width == 0 || height == 0,
           let image = image {
            width = image.size.width
            height = image.size.height
            if !isPlaceholder {
                message.setLateFilingMediaSize(width: width, height: height, duration: 0)
            }
        }
        setAspectRatio(width: width, height: height)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentImageView.image = nil
        contentImageView.sd_cancelCurrentImageLoad()
        contentImageIsPlaceholder = true
        tag = -1
    }
}

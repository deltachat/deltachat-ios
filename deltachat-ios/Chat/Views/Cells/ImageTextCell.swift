import Foundation
import UIKit
import DcCore
import SDWebImage

class ImageTextCell: BaseMessageCell {
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

    /// The play button view to display on video messages.
    open lazy var playButtonView: PlayButtonView = {
        let playButtonView = PlayButtonView()
        playButtonView.isHidden = true
        translatesAutoresizingMaskIntoConstraints = false
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

    override func update(msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool) {
        messageLabel.text = msg.text
        bottomCompactView = msg.text?.isEmpty ?? true
        mainContentView.spacing = msg.text?.isEmpty ?? false ? 0 : 6
        topCompactView = msg.quoteText == nil ? true : false
        tag = msg.id
        if msg.type == DC_MSG_IMAGE, let image = msg.image {
            contentImageView.image = image
            accessibilityLabel = String.localized("image")
            playButtonView.isHidden = true
            setAspectRatioFor(message: msg)
        } else if msg.type == DC_MSG_GIF, let url = msg.fileURL {
            contentImageView.sd_setImage(with: url,
                                         placeholderImage: UIImage(color: UIColor.init(alpha: 0,
                                                                                       red: 255,
                                                                                       green: 255,
                                                                                       blue: 255),
                                                                   size: CGSize(width: 500, height: 500)))
            playButtonView.isHidden = true
            accessibilityLabel = String.localized("gif")
            setAspectRatioFor(message: msg)
        } else if msg.type == DC_MSG_VIDEO, let url = msg.fileURL {
            playButtonView.isHidden = false
            accessibilityLabel = String.localized("video")
            if let image = ThumbnailCache.shared.restoreImage(key: url.absoluteString) {
                contentImageView.image = image
                setAspectRatioFor(message: msg, with: image, isPlaceholder: false)
            } else {
                // no image in cache
                let placeholderImage = UIImage(color: UIColor.init(alpha: 0,
                                                                   red: 255,
                                                                   green: 255,
                                                                   blue: 255),
                                               size: CGSize(width: 250, height: 250))
                contentImageView.image = placeholderImage
                DispatchQueue.global(qos: .userInteractive).async {
                    let thumbnailImage = DcUtils.generateThumbnailFromVideo(url: url)
                    if let thumbnailImage = thumbnailImage {
                        DispatchQueue.main.async { [weak self] in
                            if msg.id == self?.tag {
                                self?.contentImageView.image = thumbnailImage
                                ThumbnailCache.shared.storeImage(image: thumbnailImage, key: url.absoluteString)
                            }
                        }
                    }
                }
                setAspectRatioFor(message: msg, with: placeholderImage, isPlaceholder: true)
            }
        }
        super.update(msg: msg, messageStyle: messageStyle, showAvatar: showAvatar, showName: showName)
    }

    @objc func onImageTapped() {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            baseDelegate?.imageTapped(indexPath: indexPath)
        }
    }

    private func setAspectRatio(width: CGFloat, height: CGFloat) {
        if height == 0 || width == 0 {
            return
        }
        var width = width
        var height = height

        let orientation = UIApplication.shared.statusBarOrientation
        self.imageHeightConstraint?.isActive = false
        self.imageWidthConstraint?.isActive = false
        
        // check if image has the allowed minimal width
        if width < minImageWidth {
            height = (height / width) * minImageWidth
            width = minImageWidth
        }
        
        if  height > width {
            // show square image for portrait images
            // restrict width to half of the screen in device landscape and to 5 / 6 in portrait
            // it results in a good balance between message text width and image size
            let factor: CGFloat = orientation.isLandscape ? 1 / 2 : 5 / 6
            var squareSize  = UIScreen.main.bounds.width * factor

            //reduce the image square size if there's no message text so that it fits best in the viewable area
            if squareSize > UIScreen.main.bounds.height * 5 / 8 && (messageLabel.text?.isEmpty ?? true) {
                squareSize = UIScreen.main.bounds.height * 5 / 8
            }
            imageHeightConstraint = self.contentImageView.heightAnchor.constraint(lessThanOrEqualToConstant: squareSize)
            imageWidthConstraint = self.contentImageView.widthAnchor.constraint(lessThanOrEqualToConstant: squareSize)
        } else {
            // show image in aspect ratio for landscape images
            if orientation.isLandscape && height > UIScreen.main.bounds.height * 5 / 8 {
                //shrink landscape image in landscape device orientation if image height is too big
                self.imageHeightConstraint = self.contentImageView.heightAnchor.constraint(lessThanOrEqualToConstant: UIScreen.main.bounds.height * 5 / 8)
                self.imageWidthConstraint = self.contentImageView.widthAnchor.constraint(lessThanOrEqualTo: self.contentImageView.heightAnchor,
                                                                                         multiplier: width/height)
            } else {
                if width == minImageWidth {
                    // very small width images should be forced to not be scaled down further
                    self.imageWidthConstraint = self.contentImageView.widthAnchor.constraint(greaterThanOrEqualToConstant: width)
                } else {
                    // large width images might scale down until the max allowed text width
                    self.imageWidthConstraint = self.contentImageView.widthAnchor.constraint(lessThanOrEqualToConstant: width)
                }
                self.imageHeightConstraint = self.contentImageView.heightAnchor.constraint(
                    lessThanOrEqualTo: self.contentImageView.widthAnchor,
                    multiplier: height / width
                )
            }
        }
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
        setAspectRatio(width: width, height: height)
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
        tag = -1
    }
}

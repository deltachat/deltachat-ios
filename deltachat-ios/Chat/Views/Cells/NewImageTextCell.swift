import Foundation
import UIKit
import DcCore
import SDWebImage

class NewImageTextCell: BaseMessageCell {

    var imageHeightConstraint: NSLayoutConstraint?
    var imageWidthConstraint: NSLayoutConstraint?

    lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentHuggingPriority(.defaultLow, for: .vertical)
        label.font = UIFont.preferredFont(for: .body, weight: .regular)
        return label
    }()


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
        contentImageView.constraintAlignLeadingMaxTo(mainContentView).isActive = true
        contentImageView.constraintAlignTrailingMaxTo(mainContentView).isActive = true
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onImageTapped))
        gestureRecognizer.numberOfTapsRequired = 1
        contentImageView.addGestureRecognizer(gestureRecognizer)
    }

    override func update(msg: DcMsg, messageStyle: UIRectCorner, isAvatarVisible: Bool) {
        messageLabel.text = msg.text
        tag = msg.id
        if msg.type == DC_MSG_IMAGE, let image = msg.image {
            contentImageView.image = image
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
            setAspectRatioFor(message: msg)
        } else if msg.type == DC_MSG_VIDEO, let url = msg.fileURL {
            playButtonView.isHidden = false
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
        super.update(msg: msg, messageStyle: messageStyle, isAvatarVisible: isAvatarVisible)
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
        self.imageHeightConstraint?.isActive = false
        self.imageWidthConstraint?.isActive = false
        self.imageWidthConstraint = self.contentImageView.widthAnchor.constraint(lessThanOrEqualToConstant: width)
        self.imageHeightConstraint = self.contentImageView.heightAnchor.constraint(
            lessThanOrEqualTo: self.contentImageView.widthAnchor,
            multiplier: height / width
        )
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
        contentImageView.image = nil
        messageLabel.text = nil
        messageLabel.attributedText = nil
        tag = -1
    }
}

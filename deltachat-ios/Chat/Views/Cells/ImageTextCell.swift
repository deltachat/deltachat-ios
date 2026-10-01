import Foundation
import UIKit
import DcCore
import SDWebImage

class ImageTextCell: BaseMessageCell, ReusableCell {

    static let reuseIdentifier = "ImageTextCell"

    let minImageWidth: CGFloat = 140
    let minImageWidthWithText: CGFloat = 200
    let maxImageHeight: CGFloat = 450
    let maxStickerWidth: CGFloat = 220
    @ActivatedWhenSet var minImageWidthConstraint: NSLayoutConstraint?
    @ActivatedWhenSet var imageAspectRatioConstraint: NSLayoutConstraint?
    var stickerMaxWidthConstraint: NSLayoutConstraint?

    lazy var contentImageView: SDAnimatedImageView = {
        let imageView = SDAnimatedImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        imageView.isUserInteractionEnabled = true
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
        NSLayoutConstraint.activate([
            playButtonView.centerXAnchor.constraint(equalTo: contentImageView.centerXAnchor),
            playButtonView.centerYAnchor.constraint(equalTo: contentImageView.centerYAnchor),
            playButtonView.widthAnchor.constraint(equalToConstant: 50),
            playButtonView.heightAnchor.constraint(equalToConstant: 50),
        ])
        mainContentView.addArrangedSubview(contentImageView)
        mainContentView.addArrangedSubview(messageLabel)
        messageLabel.paddingLeading = 12
        messageLabel.paddingTrailing = 12
        contentImageView.widthAnchor.constraint(equalTo: mainContentView.widthAnchor).isActive = true
        minImageWidthConstraint = contentImageView.widthAnchor.constraint(greaterThanOrEqualToConstant: minImageWidth)
        contentImageView.heightAnchor.constraint(lessThanOrEqualToConstant: maxImageHeight).isActive = true
        imageAspectRatioConstraint = contentImageView.heightAnchor.constraint(equalTo: contentImageView.widthAnchor, multiplier: 1)
        stickerMaxWidthConstraint = contentImageView.widthAnchor.constraint(lessThanOrEqualToConstant: maxStickerWidth)
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onImageTapped))
        gestureRecognizer.numberOfTapsRequired = 1
        contentImageView.addGestureRecognizer(gestureRecognizer)
    }

    override func update(dcContext: DcContext, msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, showViewCount: Bool, searchText: String? = nil, highlight: Bool) {
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
        minImageWidthConstraint?.constant = msg.hasText ? minImageWidthWithText : minImageWidth
        stickerMaxWidthConstraint?.isActive = msg.type == DC_MSG_STICKER
        contentImageView.contentMode = msg.type == DC_MSG_STICKER ? .scaleAspectFit : .scaleAspectFill

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
                     showViewCount: showViewCount,
                     searchText: searchText,
                     highlight: highlight)
    }

    @objc func onImageTapped() {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            baseDelegate?.imageTapped(indexPath: indexPath, previewError: contentImageIsPlaceholder)
        }
    }

    private func setAspectRatioFor(message: DcMsg, with image: UIImage? = nil, isPlaceholder: Bool = false) {
        var width = message.messageWidth
        var height = message.messageHeight
        if width == 0 || height == 0, let image = image ?? message.image {
            width = image.size.width
            height = image.size.height
            if !isPlaceholder {
                message.setLateFilingMediaSize(width: width, height: height, duration: 0)
            }
        }

        let minWidth = minImageWidthConstraint?.constant ?? minImageWidth
        let ratio = height == 0 || width == 0 ? 1 : max(0.2, min(height/width, maxImageHeight/minWidth))
        imageAspectRatioConstraint = contentImageView.heightAnchor.constraint(equalTo: contentImageView.widthAnchor, multiplier: ratio)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentImageView.image = nil
        contentImageView.sd_cancelCurrentImageLoad()
        contentImageIsPlaceholder = true
        tag = -1
    }
}

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
        return label
    }()


    lazy var contentImageView: SDAnimatedImageView = {
        let imageView = SDAnimatedImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return imageView
    }()

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addArrangedSubview(contentImageView)
        mainContentView.addArrangedSubview(messageLabel)
        contentImageView.constraintAlignLeadingMaxTo(mainContentView).isActive = true
        contentImageView.constraintAlignTrailingMaxTo(mainContentView).isActive = true
    }

    override func update(msg: DcMsg, messageStyle: UIRectCorner, isAvatarVisible: Bool) {
        messageLabel.text = msg.text
        if msg.type == DC_MSG_IMAGE, let image = msg.image {
            contentImageView.image = image
        } else if msg.type == DC_MSG_GIF, let url = msg.fileURL {
            contentImageView.sd_setImage(with: url,
                                         placeholderImage: UIImage(color: UIColor.init(alpha: 0,
                                                                                       red: 255,
                                                                                       green: 255,
                                                                                       blue: 255),
                                                                   size: CGSize(width: 500, height: 500)))
        }
        setAspectRatioFor(msg: msg)
        super.update(msg: msg, messageStyle: messageStyle, isAvatarVisible: isAvatarVisible)
    }

    private func setAspectRatioFor(msg: DcMsg) {
        guard let image = msg.image else {
           return
       }

       self.imageHeightConstraint?.isActive = false
       self.imageWidthConstraint?.isActive = false
       var messageWidth = msg.messageWidth
       var messageHeight = msg.messageHeight
       if messageWidth == 0 || messageHeight == 0 {
           messageWidth = image.size.width
           messageHeight = image.size.height
           msg.setLateFilingMediaSize(width: messageWidth, height: messageHeight, duration: 0)
       }

       self.imageWidthConstraint = self.contentImageView.widthAnchor.constraint(lessThanOrEqualToConstant: messageWidth)
       self.imageHeightConstraint = self.contentImageView.heightAnchor.constraint(
           lessThanOrEqualTo: self.contentImageView.widthAnchor,
           multiplier: messageHeight / messageWidth
       )
       self.imageHeightConstraint?.isActive = true
       self.imageWidthConstraint?.isActive = true

 }

    override func prepareForReuse() {
        contentImageView.image = nil
        messageLabel.text = nil
        messageLabel.attributedText = nil
    }
}

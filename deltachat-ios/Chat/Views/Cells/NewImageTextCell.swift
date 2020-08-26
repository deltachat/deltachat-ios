import Foundation
import UIKit
import DcCore
import SDWebImage

class NewImageTextCell: BaseMessageCell {

    var imageAspectRatioConstraint: NSLayoutConstraint?
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
        contentImageView.widthAnchor.constraint(equalTo: mainContentView.widthAnchor).isActive = true
    }

    override func update(msg: DcMsg, messageStyle: UIRectCorner, isAvatarVisible: Bool) {
        messageLabel.text = msg.text
        if msg.type == DC_MSG_IMAGE, let image = msg.image {
            contentImageView.image = image
            setAspectRatioFor(image: image)
        } else if msg.type == DC_MSG_GIF, let url = msg.fileURL {
            contentImageView.sd_setImage(with: url) { (image, _, _, _) in
                if let image = image {
                    self.setAspectRatioFor(image: image)
                }
            }
        }
        super.update(msg: msg, messageStyle: messageStyle, isAvatarVisible: isAvatarVisible)
    }

    private func setAspectRatioFor(image: UIImage) {
        self.imageAspectRatioConstraint?.isActive = false
        self.imageAspectRatioConstraint = self.contentImageView.heightAnchor.constraint(
            equalTo: self.contentImageView.widthAnchor,
            multiplier: image.size.height / image.size.width)
        self.imageAspectRatioConstraint?.isActive = true
    }

    override func prepareForReuse() {
        contentImageView.image = nil
        messageLabel.text = nil
        messageLabel.attributedText = nil
    }
}

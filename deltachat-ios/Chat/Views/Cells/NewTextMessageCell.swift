import Foundation
import DcCore
import UIKit

class NewTextMessageCell: BaseMessageCell {

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addArrangedSubview(messageLabel)
        messageLabel.paddingLeading = 12
        messageLabel.paddingTrailing = 12
    }

    override func update(msg: DcMsg, messageStyle: UIRectCorner, isAvatarVisible: Bool, isGroup: Bool) {
        messageLabel.text = msg.text
        super.update(msg: msg, messageStyle: messageStyle, isAvatarVisible: isAvatarVisible, isGroup: isGroup)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
}

import Foundation
import DcCore
import UIKit

class TextMessageCell: BaseMessageCell {

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addArrangedSubview(messageLabel)
        messageLabel.paddingLeading = 12
        messageLabel.paddingTrailing = 12
    }

    override func update(msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool) {
        messageLabel.text = msg.text
        super.update(msg: msg, messageStyle: messageStyle, showAvatar: showAvatar, showName: showName)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
}

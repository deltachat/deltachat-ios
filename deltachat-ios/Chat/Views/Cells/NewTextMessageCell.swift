import Foundation
import DcCore
import UIKit

class NewTextMessageCell: BaseMessageCell {

    lazy var messageLabel: PaddingTextView = {
        let paddingView = PaddingTextView(top: 0, left: 12, bottom: 0, right: 12)
        paddingView.translatesAutoresizingMaskIntoConstraints = false
        paddingView.font = UIFont.preferredFont(for: .body, weight: .regular)
        return paddingView
    }()

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addArrangedSubview(messageLabel)
    }

    override func update(msg: DcMsg, messageStyle: UIRectCorner, isAvatarVisible: Bool, isGroup: Bool) {
        messageLabel.text = msg.text
        super.update(msg: msg, messageStyle: messageStyle, isAvatarVisible: isAvatarVisible, isGroup: isGroup)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
        messageLabel.attributedText = nil
    }
    
}

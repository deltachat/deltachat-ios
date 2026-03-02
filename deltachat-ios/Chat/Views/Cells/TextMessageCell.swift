import Foundation
import DcCore
import UIKit

class TextMessageCell: BaseMessageCell, ReusableCell {

    static let reuseIdentifier = "TextMessageCell"

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addArrangedSubview(messageLabel)
        messageLabel.paddingLeading = 12
        messageLabel.paddingTrailing = 12
    }

    override func update(dcContext: DcContext, msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, showViewCount: Bool, searchText: String?, highlight: Bool) {
        if msg.type == DC_MSG_CALL {
            msg.text = "📞 " + (msg.text ?? "")
        }

        messageLabel.text = msg.text

        super.update(dcContext: dcContext,
                     msg: msg,
                     messageStyle: messageStyle,
                     showAvatar: showAvatar,
                     showName: showName,
                     showViewCount: showViewCount,
                     searchText: searchText,
                     highlight: highlight)
    }
}

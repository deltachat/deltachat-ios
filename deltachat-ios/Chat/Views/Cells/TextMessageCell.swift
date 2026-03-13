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
}

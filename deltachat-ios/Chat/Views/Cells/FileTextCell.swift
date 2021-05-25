import Foundation
import UIKit
import DcCore
import SDWebImage

class FileTextCell: BaseMessageCell {

    private var spacer: NSLayoutConstraint?

    private lazy var fileView: FileView = {
        let view = FileView()
        return view
    }()

    override func setupSubviews() {
        super.setupSubviews()
        let spacerView = UIView()
        spacer = spacerView.constraintHeightTo(8, priority: .defaultHigh)
        spacer?.isActive = true
        mainContentView.addArrangedSubview(fileView)
        mainContentView.addArrangedSubview(spacerView)
        mainContentView.addArrangedSubview(messageLabel)
        fileView.horizontalLayout = true
        mainContentViewHorizontalPadding = 12
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        fileView.prepareForReuse()
    }

    override func update(msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, showFreshMessageSeparator: Bool) {
        if let text = msg.text, !text.isEmpty {
            messageLabel.text = text
            spacer?.isActive = true
        } else {
            spacer?.isActive = false
        }
        
        fileView.configure(message: msg)
        accessibilityLabel = "\(String.localized("document")), \(fileView.configureAccessibilityLabel())"
        super.update(msg: msg, messageStyle: messageStyle, showAvatar: showAvatar, showName: showName, showFreshMessageSeparator: showFreshMessageSeparator)
    }
    
}

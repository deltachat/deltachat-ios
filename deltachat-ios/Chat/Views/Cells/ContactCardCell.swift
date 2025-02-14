import Foundation
import UIKit
import DcCore
import SDWebImage

public class ContactCardCell: BaseMessageCell, ReusableCell {

    static let reuseIdentifier = "ContactCardCell"

    private var spacerHeight: NSLayoutConstraint?
    var spacerWidth: NSLayoutConstraint?

    lazy var contactView = ContactCardView()

    override func setupSubviews() {
        super.setupSubviews()
        let spacerView = UIView()
        spacerHeight = spacerView.constraintHeightTo(8, priority: .defaultHigh)
        spacerHeight?.isActive = true
        spacerWidth = spacerView.constraintWidthTo(280, priority: UILayoutPriority(rawValue: 400))
        mainContentView.addArrangedSubview(contactView)
        mainContentView.addArrangedSubview(spacerView)
        mainContentView.addArrangedSubview(messageLabel)
        mainContentViewHorizontalPadding = 12
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        contactView.prepareForReuse()
    }

    override func update(dcContext: DcContext, msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, searchText: String? = nil, highlight: Bool) {
        if let text = msg.text, !text.isEmpty {
            messageLabel.text = text
            spacerHeight?.isActive = true
        } else {
            spacerHeight?.isActive = false
        }

        contactView.configure(message: msg, dcContext: dcContext)
        a11yDcType = "\(String.localized("document")), \(contactView.configureAccessibilityLabel())"
        super.update(dcContext: dcContext,
                     msg: msg,
                     messageStyle: messageStyle,
                     showAvatar: showAvatar,
                     showName: showName,
                     searchText: searchText,
                     highlight: highlight)
    }

}

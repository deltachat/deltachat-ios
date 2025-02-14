import Foundation
import UIKit
import DcCore
import SDWebImage

public class FileTextCell: BaseMessageCell, ReusableCell {

    class var reuseIdentifier: String { "FileTextCell" }

    private var spacerHeight: NSLayoutConstraint?
    var spacerWidth: NSLayoutConstraint?

    lazy var fileView: FileView = {
        let view = FileView()
        return view
    }()

    override func setupSubviews() {
        super.setupSubviews()
        let spacerView = UIView()
        spacerHeight = spacerView.constraintHeightTo(8, priority: .defaultHigh)
        spacerHeight?.isActive = true
        spacerWidth = spacerView.constraintWidthTo(280, priority: UILayoutPriority(rawValue: 400))
        mainContentView.addArrangedSubview(fileView)
        mainContentView.addArrangedSubview(spacerView)
        mainContentView.addArrangedSubview(messageLabel)
        fileView.horizontalLayout = true
        mainContentViewHorizontalPadding = 12
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        fileView.prepareForReuse()
    }

    override func update(dcContext: DcContext, msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, searchText: String? = nil, highlight: Bool) {
        if let text = msg.text, !text.isEmpty {
            messageLabel.text = text
            spacerHeight?.isActive = true
        } else {
            spacerHeight?.isActive = false
        }
        
        fileView.configure(message: msg)
        a11yDcType = "\(String.localized("document")), \(fileView.configureAccessibilityLabel())"
        super.update(dcContext: dcContext,
                     msg: msg,
                     messageStyle: messageStyle,
                     showAvatar: showAvatar,
                     showName: showName,
                     searchText: searchText,
                     highlight: highlight)
    }
    
}

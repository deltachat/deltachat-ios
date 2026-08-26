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
        let heightConstraint = spacerView.heightAnchor.constraint(equalToConstant: 8)
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true
        spacerHeight = heightConstraint
        let widthConstraint = spacerView.widthAnchor.constraint(equalToConstant: 280)
        widthConstraint.priority = UILayoutPriority(rawValue: 400)
        spacerWidth = widthConstraint
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

    override func update(dcContext: DcContext, msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, showViewCount: Bool, searchText: String? = nil, highlight: Bool) {
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
                     showViewCount: showViewCount,
                     searchText: searchText,
                     highlight: highlight)
    }
    
}

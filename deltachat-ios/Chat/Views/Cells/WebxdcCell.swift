import UIKit
import DcCore

public class WebxdcCell: FileTextCell {

    override class var reuseIdentifier: String { "WebxdcCell" }

    override func setupSubviews() {
        super.setupSubviews()
        fileView.fileImageView.isUserInteractionEnabled = true
        fileView.horizontalLayout = false
        spacerWidth?.isActive = true
    }

    override func update(dcContext: DcContext, msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, searchText: String? = nil, highlight: Bool) {
        super.update(dcContext: dcContext,
                     msg: msg,
                     messageStyle: messageStyle,
                     showAvatar: showAvatar,
                     showName: showName,
                     searchText: searchText,
                     highlight: highlight)
        a11yDcType = fileView.configureAccessibilityLabel()
    }
}

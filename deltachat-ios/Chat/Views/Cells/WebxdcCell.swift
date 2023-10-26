import UIKit
import DcCore

public class WebxdcCell: FileTextCell {

    override func setupSubviews() {
        super.setupSubviews()
        fileView.fileImageView.isUserInteractionEnabled = true
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onImageTapped))
        fileView.fileImageView.addGestureRecognizer(gestureRecognizer)
        fileView.horizontalLayout = false
        spacerWidth?.isActive = true
    }

    @objc func onImageTapped() {
        if let tableView = self.superview as? UITableView, let indexPath = tableView.indexPath(for: self) {
            baseDelegate?.imageTapped(indexPath: indexPath, previewError: false)
        }
    }

    override func update(dcContext: DcContext, msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, searchText: String? = nil, highlight: Bool) {
        super.update(dcContext: dcContext,
                     msg: msg,
                     messageStyle: messageStyle,
                     showAvatar: showAvatar,
                     showName: showName,
                     searchText: searchText,
                     highlight: highlight)
        accessibilityLabel = fileView.configureAccessibilityLabel()
    }
}

import UIKit
import DcCore

public class WebxdcCell: BaseMessageCell {
    
    private var spacer: NSLayoutConstraint?
    
    private lazy var webxdcView: WebxdcPreview = {
        let view = WebxdcPreview()
        return view
    }()
    

    override func setupSubviews() {
        super.setupSubviews()
        let spacerView = UIView()
        spacer = spacerView.constraintHeightTo(8, priority: .defaultHigh)
        spacer?.isActive = true
        spacerView.constraintWidthTo(300, priority: UILayoutPriority(rawValue: 400)).isActive = true
        mainContentView.addArrangedSubview(webxdcView)
        mainContentView.addArrangedSubview(spacerView)
        mainContentView.addArrangedSubview(messageLabel)
        mainContentViewHorizontalPadding = 12
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        webxdcView.prepareForReuse()
    }

    override func update(dcContext: DcContext, msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, searchText: String? = nil, highlight: Bool) {
        if let text = msg.text, !text.isEmpty {
            messageLabel.text = text
            spacer?.isActive = true
        } else {
            spacer?.isActive = false
        }
        
        webxdcView.configure(message: msg)
        accessibilityLabel = "\(webxdcView.configureAccessibilityLabel())"
        super.update(dcContext: dcContext,
                     msg: msg,
                     messageStyle: messageStyle,
                     showAvatar: showAvatar,
                     showName: showName,
                     searchText: searchText,
                     highlight: highlight)
    }
}

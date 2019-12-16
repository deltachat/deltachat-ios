import UIKit

class PaddingLabel: UILabel {

    var topInset: CGFloat = 16
    var bottomInset: CGFloat = 16
    var leftInset: CGFloat = 16
    var rightInset: CGFloat = 16

    required init() {
        super.init(frame: CGRect.zero)
        numberOfLines = 0

        sizeToFit()
        layer.cornerRadius = 16
        clipsToBounds = true
        self.translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        get {
            var contentSize = super.intrinsicContentSize
            contentSize.height += topInset + bottomInset
            contentSize.width += leftInset + rightInset
            return contentSize
        }
    }
}

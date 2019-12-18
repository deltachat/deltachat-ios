import UIKit

class PaddingLabel: UILabel {

    var contentInsets = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)

    required init() {
        super.init(frame: CGRect.zero)
        numberOfLines = 0
        layer.cornerRadius = 12
        clipsToBounds = true
        self.translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var text: String? {
        set {
            guard let newValue = newValue else {
                attributedText = nil
                return
            }

            guard let style = NSMutableParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle else {
                attributedText = NSAttributedString(string: newValue)
                return
            }

            style.alignment = NSTextAlignment.natural
            style.firstLineHeadIndent = 12.0
            style.headIndent = 12.0
            style.tailIndent = -12.0
            style.lineBreakMode = .byWordWrapping
            attributedText = NSAttributedString(string: newValue, attributes: [.paragraphStyle: style])
        }

        get {
            return self.attributedText?.string
        }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        return addInsets(to: super.intrinsicContentSize)
    }

    private func addInsets(to size: CGSize) -> CGSize {
        let width = size.width + contentInsets.left + contentInsets.right
        let height = size.height + contentInsets.top + contentInsets.bottom
        return CGSize(width: width, height: height)
    }
}

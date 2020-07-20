import UIKit

public class EmptyStateLabel: FlexLabel {

    public override var text: String? {
        set {
            guard let newValue = newValue else {
                super.label.attributedText = nil
                return
            }

            guard let style = NSMutableParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle else {
                label.attributedText = NSAttributedString(string: newValue)
                return
            }
            style.alignment = NSTextAlignment.natural
            style.lineBreakMode = .byWordWrapping
            attributedText = NSAttributedString(
                string: newValue,
                attributes: [.paragraphStyle: style]
            )
        }
        get {
            return super.label.text
        }
    }

    public override init() {
        super.init()
        label.backgroundColor = DcColors.systemMessageBackgroundColor
        label.textColor = DcColors.defaultTextColor
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

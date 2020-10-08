import UIKit
public class PaddingTextView: UIView {

    public lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    let insets: UIEdgeInsets

    public var text: String? {
        set {
            label.text = newValue
        }
        get {
            return label.text
        }
    }

    public var attributedText: NSAttributedString? {
        set {
            label.attributedText = newValue
        }
        get {
            return label.attributedText
        }
    }

    public var numberOfLines: Int {
        set {
            label.numberOfLines = newValue
        }
        get {
            return label.numberOfLines
        }
    }

    public var font: UIFont {
        set {
            label.font = newValue
        }
        get {
            return label.font
        }
    }

    init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.insets = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        super.init(frame: .zero)
        setupView()
    }

    func setupView() {
        addSubview(label)
        addConstraints([
            label.constraintAlignLeadingTo(self, paddingLeading: insets.left),
            label.constraintAlignTrailingTo(self, paddingTrailing: insets.right),
            label.constraintAlignTopTo(self, paddingTop: insets.top),
            label.constraintAlignBottomTo(self, paddingBottom: insets.bottom)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

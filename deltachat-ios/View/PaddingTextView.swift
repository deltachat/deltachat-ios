import UIKit
public class PaddingTextView: UIView {

    public lazy var label: MessageLabel = {
        let label = MessageLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.isUserInteractionEnabled = true
        return label
    }()

    public var paddingTop: CGFloat = 0 {
        didSet { containerTopConstraint.constant = paddingTop }
    }

    public var paddingBottom: CGFloat = 0 {
        didSet { containerBottomConstraint.constant = -paddingBottom }
    }

    public var paddingLeading: CGFloat = 0 {
        didSet { containerLeadingConstraint.constant = paddingLeading }
    }

    public var paddingTrailing: CGFloat = 0 {
        didSet { containerTailingConstraint.constant = -paddingTrailing }
    }

    private lazy var containerLeadingConstraint: NSLayoutConstraint = {
        return label.constraintAlignLeadingTo(self)
    }()
    private lazy var containerTailingConstraint: NSLayoutConstraint = {
        return label.constraintAlignTrailingTo(self)
    }()
    private lazy var containerTopConstraint: NSLayoutConstraint = {
        return label.constraintAlignTopTo(self)
    }()
    private lazy var containerBottomConstraint: NSLayoutConstraint = {
        return label.constraintAlignBottomTo(self)
    }()

    public var text: String? {
        get { return label.text }
        set { label.text = newValue }
    }

    public var attributedText: NSAttributedString? {
        get { return label.attributedText }
        set { label.attributedText = newValue }
    }

    public var numberOfLines: Int {
        get { return label.numberOfLines }
        set { label.numberOfLines = newValue }
    }

    public var font: UIFont {
        get { return label.font }
        set { label.font = newValue }
    }

    public var textColor: UIColor {
        get { return label.textColor }
        set { label.textColor = newValue }
    }

    public var enabledDetectors: [DetectorType] {
        get { return label.enabledDetectors }
        set { label.enabledDetectors = newValue }
    }

    public var delegate: MessageLabelDelegate? {
        get { return label.delegate }
        set { label.delegate = newValue }
    }

    init() {
        super.init(frame: .zero)
        addSubview(label)
        addConstraints([
            containerTailingConstraint,
            containerLeadingConstraint,
            containerBottomConstraint,
            containerTopConstraint
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

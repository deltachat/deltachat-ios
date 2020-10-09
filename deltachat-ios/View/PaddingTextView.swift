import UIKit
public class PaddingTextView: UIView {

    public lazy var label: NewMessageLabel = {
        let label = NewMessageLabel()
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
        set { label.text = newValue }
        get { return label.text }
    }

    public var attributedText: NSAttributedString? {
        set { label.attributedText = newValue }
        get { return label.attributedText }
    }

    public var numberOfLines: Int {
        set { label.numberOfLines = newValue }
        get { return label.numberOfLines }
    }

    public var font: UIFont {
        set { label.font = newValue }
        get { return label.font }
    }

    public var enabledDetectors: [DetectorType] {
        set { label.enabledDetectors = newValue }
        get { return label.enabledDetectors }
    }

    public var delegate: MessageLabelDelegate? {
        set { label.delegate = newValue }
        get { return label.delegate }
    }

    convenience init() {
        self.init(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        super.init(frame: .zero)
        addSubview(label)
        paddingLeading = left
        paddingTop = top
        paddingBottom = bottom
        paddingTrailing = right
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

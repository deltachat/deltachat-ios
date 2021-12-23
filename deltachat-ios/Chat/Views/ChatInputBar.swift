import UIKit
import DcCore


public class ChatInputBar: InputBarAccessoryView {

    var hasDraft: Bool = false
    var hasQuote: Bool = false
    
    var onScrollDownButtonPressed: (() -> Void)?
    
    lazy var scrollDownButton: UIButton = {
        let button = UIButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(onScrollDownPressed), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    public convenience init() {
        self.init(frame: .zero)
    }

    override open func setup() {
        replaceInputBar()
        setupScrollDownButton()
        super.setup()
        backgroundColor = .clear
        backgroundView.backgroundColor = DcColors.defaultTransparentBackgroundColor
        insertSubview(blurView, at: 0)
        blurView.fillSuperview()
    }
    
    @objc func onScrollDownPressed() {
        if let callback = onScrollDownButtonPressed {
            callback()
        }
    }

    func replaceInputBar() {
        inputTextView = ChatInputTextView()
        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        inputTextView.inputBarAccessoryView = self
    }
    
    override open func calculateMaxTextViewHeight() -> CGFloat {
        if traitCollection.verticalSizeClass == .regular || UIDevice.current.userInterfaceIdiom == .pad {
            let divisor: CGFloat = 3
            var subtract: CGFloat = 0
            subtract += hasDraft ? 90 : 0
            subtract += hasQuote ? 90 : 0
            let height = (UIScreen.main.bounds.height / divisor).rounded(.down) - subtract
            if height < 40 {
                return 40
            }
            return height
        } else {
            // landscape phone layout
            let height = UIScreen.main.bounds.height - keyboardHeight - 12
            logger.debug("HEIGHTS: calculateMaxTextViewHeight screen \(UIScreen.main.bounds.height) - \(keyboardHeight) >> \(UIScreen.main.bounds.height - keyboardHeight)")
            return height
        }
    }

    public func configure(draft: DraftModel) {
        hasDraft = !draft.isEditing && draft.attachment != nil
        hasQuote = !draft.isEditing && draft.quoteText != nil
        leftStackView.isHidden = draft.isEditing
        rightStackView.isHidden = draft.isEditing
        maxTextViewHeight = calculateMaxTextViewHeight()
    }

    public func cancel() {
        hasDraft = false
        hasQuote = false
        maxTextViewHeight = calculateMaxTextViewHeight()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        scrollDownButton.layer.borderColor = DcColors.colorDisabled.cgColor
    }

    
    
    func setupScrollDownButton() {
        self.addSubview(scrollDownButton)
        NSLayoutConstraint.activate([
            scrollDownButton.constraintAlignTopTo(self, paddingTop: -52),
            scrollDownButton.constraintAlignTrailingToAnchor(self.safeAreaLayoutGuide.trailingAnchor, paddingTrailing: 12),
            scrollDownButton.constraintHeightTo(40),
            scrollDownButton.constraintWidthTo(40)
        ])
        scrollDownButton.backgroundColor = DcColors.defaultBackgroundColor
        scrollDownButton.setImage(UIImage(named: "ic_scrolldown")?.sd_tintedImage(with: .systemBlue), for: .normal)
        scrollDownButton.layer.cornerRadius = 20
        scrollDownButton.layer.borderColor = DcColors.colorDisabled.cgColor
        scrollDownButton.layer.borderWidth = 1
        scrollDownButton.layer.masksToBounds = true
        scrollDownButton.accessibilityLabel = String.localized("menu_scroll_to_bottom")
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !scrollDownButton.isHidden {
            let scrollButtonViewPoint = self.scrollDownButton.convert(point, from: self)
            if let view = scrollDownButton.hitTest(scrollButtonViewPoint, with: event) {
                return view
            }
        }
        return super.hitTest(point, with: event)
    }
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if !scrollDownButton.isHidden && scrollDownButton.point(inside: convert(point, to: scrollDownButton), with: event) {
            return true
        }
        return super.point(inside: point, with: event)
    }
}

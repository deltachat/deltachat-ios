import UIKit
import InputBarAccessoryView
import DcCore


public class ChatInputBar: InputBarAccessoryView {

    var hasDraft: Bool = false
    var hasQuote: Bool = false
    var keyboardHeight: CGFloat = 0

    public convenience init() {
        self.init(frame: .zero)
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupKeyboardObserver()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupKeyboardObserver()
        backgroundColor = DcColors.chatBackgroundColor
    }

    func setupKeyboardObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardChanged),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override open func calculateMaxTextViewHeight() -> CGFloat {
        if traitCollection.verticalSizeClass == .regular {
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
            // horizontal layout
            let height = UIScreen.main.bounds.height - keyboardHeight - 12
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

    @objc func keyboardChanged(_ notification: Notification) {
        if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardRectangle = keyboardFrame.cgRectValue
            invalidateIntrinsicContentSize()
            keyboardHeight = keyboardRectangle.height - intrinsicContentSize.height
            updateTextViewHeight()
            delegate?.inputBar(self, didChangeIntrinsicContentTo: intrinsicContentSize)
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if (self.traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass)
                || (self.traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass) {
            invalidateIntrinsicContentSize()
            updateTextViewHeight()
            delegate?.inputBar(self, didChangeIntrinsicContentTo: intrinsicContentSize)
        }
    }

    private func updateTextViewHeight() {
        maxTextViewHeight = calculateMaxTextViewHeight()
        if keyboardHeight > 0, UIApplication.shared.statusBarOrientation.isLandscape {
            setShouldForceMaxTextViewHeight(to: true, animated: false)
        } else if shouldForceTextViewMaxHeight {
            setShouldForceMaxTextViewHeight(to: false, animated: false)
        }
    }
}

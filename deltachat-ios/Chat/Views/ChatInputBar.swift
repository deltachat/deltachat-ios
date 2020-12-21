import UIKit
import InputBarAccessoryView


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
    }

    func setupKeyboardObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardChanged),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardChanged),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
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
        hasDraft = draft.draftAttachment != nil
        hasQuote = draft.quoteText != nil
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
            keyboardHeight = keyboardRectangle.height - intrinsicContentSize.height
            maxTextViewHeight = calculateMaxTextViewHeight()
            logger.debug("keyboard height: \(keyboardHeight) - intrinsic content size:  \(intrinsicContentSize.height)")
            forceMaxTextViewHeightForHorizontalLayout()
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if (self.traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass)
                || (self.traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass) {
            forceMaxTextViewHeightForHorizontalLayout()
        }
    }

    private func forceMaxTextViewHeightForHorizontalLayout() {
        if keyboardHeight > 0, UIApplication.shared.statusBarOrientation.isLandscape {
            setShouldForceMaxTextViewHeight(to: true, animated: false)
        } else if shouldForceTextViewMaxHeight {
            setShouldForceMaxTextViewHeight(to: false, animated: false)
        }
    }
}

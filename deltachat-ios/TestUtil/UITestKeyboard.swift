#if DEBUG
import UIKit

// MARK: Set keyboard language to English and disable autocorrection in UITests

extension UIView {
    open override var textInputMode: UITextInputMode? {
        if TestUtil.isRunningUITests {
            // Hide the autocorrection options above the keyboard
            if let textView = self as? UITextView {
                textView.autocorrectionType = .no
                textView.spellCheckingType = .no
            }
            if let textField = self as? UITextField {
                textField.autocorrectionType = .no
                textField.spellCheckingType = .no
            }

            // Make sure the keyboard is always in English in UITests for consistent screenshots
            return .activeInputModes.first(where: {
                $0.primaryLanguage == "en-US"
            }) ?? { fatalError("UITest: Missing en-US keyboard in simulator") }()
        } else {
            return super.textInputMode
        }
    }
}

#endif

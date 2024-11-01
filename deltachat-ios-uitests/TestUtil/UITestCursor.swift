// TODO: Just swizzle the tintColor of UITextView and UITextField instead of doing it manually per field
#if DEBUG
import UIKit

extension TestUtil {
    /// Set the tintColor of UITextView and UITextField to prevent the cursor from being visible in UITests.
    static func setCursorTintColor() {
        UITextField.appearance().tintColor = .clear
        UITextView.appearance().tintColor = .clear
    }
}

// MARK: Prevent the cursor tintColor changes when testing

extension UITextView {
    open override var tintColor: UIColor! {
        get { return super.tintColor }
        set { super.tintColor = TestUtil.isRunningUITests ? .clear : newValue }
    }
}

extension UITextField {
    open override var tintColor: UIColor! {
        get { return super.tintColor }
        set { super.tintColor = TestUtil.isRunningUITests ? .clear : newValue }
    }
}
#endif

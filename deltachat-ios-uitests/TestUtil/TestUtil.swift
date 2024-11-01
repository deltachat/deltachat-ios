import UIKit

struct TestUtil {
    static func didFinishLaunching(with options: [UIApplication.LaunchOptionsKey: Any]?) {
        #if DEBUG
        if isRunningUITests {
            selectUITestAccount()
            setCursorTintColor()
            // After window is created, check safe area insets
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                assert(UIApplication.shared.windows.first?.safeAreaInsets == safeAreaInsets)
            }
        }
        #endif
    }

    static var isRunningUITests: Bool {
        #if DEBUG
                return CommandLine.arguments.contains("--UITests")
        #else
                return false
        #endif
    }

    /// This provides safe area inset to UITest code that is checked on launch to ensure it is correct.
    /// This is needed because UITests can not access runtime properties like safe area.
    static var safeAreaInsets: UIEdgeInsets {
        return switch UIDevice.current.name {
        case "iPhone X": .init(top: 44, left: 0, bottom: 34, right: 0)
        case "iPhone SE (3rd generation)": .init(top: 20, left: 0, bottom: 0, right: 0)
        case "iPhone 16": .init(top: 59, left: 0, bottom: 34, right: 0)
        default: .zero
        }
    }
}

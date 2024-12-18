import UIKit

struct TestUtil {
    static func didFinishLaunching(with options: [UIApplication.LaunchOptionsKey: Any]?) {
        #if DEBUG
        if isRunningUITests {
            selectUITestAccount()
            setCursorTintColor()
            // Wait for window creation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: addSafeAreaProvider)
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
}

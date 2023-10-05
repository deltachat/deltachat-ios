import Foundation
import UIKit
import DcCore

struct Utils {

    static func isEmail(url: URL) -> Bool {
        let mailScheme = "mailto"
        if let scheme = url.scheme {
            return mailScheme == scheme && mayBeValidAddr(email: url.absoluteString.substring(mailScheme.count + 1, url.absoluteString.count))
        }
        return false
    }

    static func getEmailFrom(_ url: URL) -> String {
        let mailScheme = "mailto"
        return url.absoluteString.substring(mailScheme.count + 1, url.absoluteString.count)
    }

    public static func getBackgroundImageURL(name: String) -> URL? {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask) as [URL]
        guard let identifier = Bundle.main.bundleIdentifier else {
            logger.error("backgroundImageURL: Could not find bundle identifier")
            return nil
        }
        guard let directoryURL = urls.last else {
            logger.error("backgroundImageURL: Could not find directory url for .applicationSupportDirectory in .userDomainMask")
            return nil
        }
        return directoryURL.appendingPathComponent(identifier).appendingPathComponent(name)
    }

    public static func getSafeBottomLayoutInset() -> CGFloat {
        if #available(iOS 13.0, *) {
            let window = UIApplication.shared.windows.first
            return window?.safeAreaInsets.bottom ?? 0
        }
        // iOS 11 and 12
        let window = UIApplication.shared.keyWindow
        return window?.safeAreaInsets.bottom ?? 0
    }
}

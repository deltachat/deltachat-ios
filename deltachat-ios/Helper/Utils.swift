import Foundation
import UIKit
import DcCore

struct Utils {

    static func isValid(email: String) -> Bool {
        let emailRegEx = "(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
            + "~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
            + "x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
            + "z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
            + "]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
            + "9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
            + "-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])"

        let emailTest = NSPredicate(format: "SELF MATCHES[c] %@", emailRegEx)
        return emailTest.evaluate(with: email)
    }


    static func isEmail(url: URL) -> Bool {
        let mailScheme = "mailto"
        if let scheme = url.scheme {
            return mailScheme == scheme && isValid(email: url.absoluteString.substring(mailScheme.count + 1, url.absoluteString.count))
        }
        return false
    }

    static func getEmailFrom(_ url: URL) -> String {
        let mailScheme = "mailto"
        return url.absoluteString.substring(mailScheme.count + 1, url.absoluteString.count)
    }

    static func formatAddressForQuery(address: [String: String]) -> String {
        // Open address in Apple Maps app.
        var addressParts = [String]()
        let addAddressPart: ((String?) -> Void) = { part in
            guard let part = part else {
                return
            }
            guard !part.isEmpty else {
                return
            }
            addressParts.append(part)
        }
        addAddressPart(address["Street"])
        addAddressPart(address["Neighborhood"])
        addAddressPart(address["City"])
        addAddressPart(address["Region"])
        addAddressPart(address["Postcode"])
        addAddressPart(address["Country"])
        return addressParts.joined(separator: ", ")
    }

    static func hasAudioSuffix(url: URL) -> Bool {
        // TODO: add more file suffixes
        return url.absoluteString.hasSuffix("wav")
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

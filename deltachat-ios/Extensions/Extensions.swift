import UIKit
import Foundation
import CommonCrypto
import UniformTypeIdentifiers
import MobileCoreServices

extension Dictionary {
    func percentEscaped() -> String {
        return map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}

extension URLSession {
    func synchronousDataTask(request: URLRequest) -> (Data?, URLResponse?, Error?) {
        var data: Data?
        var response: URLResponse?
        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)

        let task = dataTask(with: request) {
            data = $0
            response = $1
            error = $2

            semaphore.signal()
        }
        task.resume()

        _ = semaphore.wait(timeout: .distantFuture)

        return (data, response, error)
    }
}

extension UIViewController {
    func hideKeyboardOnTap() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}

extension UIAlertController.Style {
    // ipad allow .actionSheet only presented for some concrete controls (and cashes otherwise!)
    // whereas iphone can present .actionSheet unconditionally.
    // .safeActionSheet returns .alert for systems that do not support .actionSheet unconditionally.
    // if in doubt, always prefer .safeActionSheet over .actionSheet
    static var safeActionSheet: UIAlertController.Style {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .alert
        } else {
            return .actionSheet
        }
    }
}

extension UIFont {
    static func preferredFont(for style: TextStyle, weight: Weight) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        let desc = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style, compatibleWith: traits)
        let font = UIFont.systemFont(ofSize: desc.pointSize, weight: weight)
        let metrics = UIFontMetrics(forTextStyle: style)
        return metrics.scaledFont(for: font)
    }

    static func preferredItalicFont(for style: TextStyle) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        let desc = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style, compatibleWith: traits)
        let font = UIFont.italicSystemFont(ofSize: desc.pointSize)
        let metrics = UIFontMetrics(forTextStyle: style)
        return metrics.scaledFont(for: font)
    }

    static func preferredBoldFont(for style: TextStyle) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        let desc = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style, compatibleWith: traits)
        let font = UIFont.boldSystemFont(ofSize: desc.pointSize)
        let metrics = UIFontMetrics(forTextStyle: style)
        return metrics.scaledFont(for: font)
    }
}

extension UINavigationController {
    // pop up to viewsToPop viewControllers from the stack
    func popViewControllers(viewsToPop: Int, animated: Bool) {
        if viewControllers.count >= 2 && viewsToPop >= 1 {
            let vc = viewControllers[max(0, viewControllers.count - viewsToPop - 1)]
            popToViewController(vc, animated: animated)
        }
    }
}

extension UILabel {
    func offsetOfSubstring(_ substring: String) -> CGFloat {
        guard let text = text else {
            return 0
        }

        let searchIndexes = text.ranges(of: substring, options: .caseInsensitive)
        guard let firstIndex = searchIndexes.first else {
            return 0
        }

        let prefix = text.substring(to: firstIndex.lowerBound)
        let size: CGSize = prefix.size(withAttributes: [NSAttributedString.Key.font: font])
        return size.height
    }
}

extension UIScrollView {
    func scrollToBottom(animated: Bool) {
        let bottomOffset = CGPoint(x: contentOffset.x,
                                   y: contentSize.height - bounds.height + adjustedContentInset.bottom)
        setContentOffset(bottomOffset, animated: animated)
    }
}

extension NSData {
    func sha1() -> String {
         var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
         CC_SHA1(bytes, CC_LONG(self.count), &digest)
         let hexBytes = digest.map { String(format: "%02hhx", $0) }
         return hexBytes.joined()
    }
}

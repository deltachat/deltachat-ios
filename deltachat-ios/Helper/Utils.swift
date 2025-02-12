import Foundation
import UIKit
import DcCore
import LocalAuthentication

extension URL {
    var isDeltaChatInvitation: Bool {
        if let host, host == Utils.inviteDomain {
            return true
        } else {
            return false
        }
    }
}
struct Utils {
    public static let inviteDomain = "i.delta.chat"

    // MARK: - Proxy

    static func isProxy(url proxyURL: URL, dcContext: DcContext) -> Bool {
        let parsedProxy = dcContext.checkQR(qrCode: proxyURL.absoluteString)

        return parsedProxy.state == DC_QR_PROXY
    }

    // MARK: - Email
    static func isEmail(url: URL) -> Bool {
        let mailScheme = "mailto"
        if let scheme = url.scheme {
            return mailScheme == scheme && DcContext.mayBeValidAddr(email: url.absoluteString.substring(mailScheme.count + 1, url.absoluteString.count))
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
        let window = UIApplication.shared.windows.first
        return window?.safeAreaInsets.bottom ?? 0
    }

    // Puts text below the given image and returns as a new image.
    // The result is ready to be used with `UIContextualAction.image` -
    // which shows the title otherwise only for large heightForRowAt (>= 91 in experiments).
    // If you add an text to an image that way, set `UIContextualAction.title` to `nil` to be safe for cornercases - or if apple changes things -
    // otherwise, one would see the title twice *drunk* :)
    static func makeImageWithText(image: UIImage?, text: String) -> UIImage? {
        guard let image = image?.withTintColor(UIColor.white) else { return nil }

        let maxLen = 11
        let shortText: String
        if text.count > maxLen {
            shortText = text.substring(0, maxLen - 1).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        } else {
            shortText = text
        }

        let spacing: CGFloat = 4
        let textAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.white]

        let textSize = shortText.size(withAttributes: textAttributes)
        let width = max(image.size.width, textSize.width)
        let height = image.size.height + spacing + textSize.height

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { _ in
            let imageOrigin = CGPoint(x: (renderer.format.bounds.width - image.size.width) / 2, y: 0)
            image.draw(at: imageOrigin)

            let textOrigin = CGPoint(x: (renderer.format.bounds.width - textSize.width) / 2, y: image.size.height + spacing)
            shortText.draw(at: textOrigin, withAttributes: textAttributes)
        }
    }

    public static func getInviteLink(context: DcContext, chatId: Int) -> String? {
        return context.getSecurejoinQr(chatId: chatId)
    }

    public static func share(message: DcMsg, parentViewController: UIViewController, sourceView: UIView? = nil, sourceItem: UIBarButtonItem? = nil) {
        guard let scrambledURL = message.fileURL else { return }

        let shareURL: URL
        if let filename = message.filename {
            let cleanURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            shareURL = FileHelper.copyIfPossible(src: scrambledURL, dest: cleanURL)
        } else {
            shareURL = scrambledURL
        }

        let objectsToShare: [Any]
        if message.type == DC_MSG_WEBXDC {
            let dict = message.getWebxdcInfoDict()
            let previewImage = message.getWebxdcPreviewImage()
            let previewText = dict["name"] as? String ?? shareURL.lastPathComponent
            objectsToShare = [WebxdcItemSource(title: previewText,
                                               previewImage: previewImage,
                                               url: shareURL)]
        } else {
            objectsToShare = [shareURL]
        }

        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        activityVC.excludedActivityTypes = [.copyToPasteboard]
        if let sourceItem {
            activityVC.popoverPresentationController?.barButtonItem = sourceItem
        } else if let sourceView {
            activityVC.popoverPresentationController?.sourceView = sourceView
        } else {
            logger.error("set sourceView or sourceItem to avoid iPad crashes")
            return
        }
        parentViewController.present(activityVC, animated: true, completion: nil)
    }

    public static func share(url: String, parentViewController: UIViewController, sourceItem: UIBarButtonItem) {
        guard let url = URL(string: url) else { return }

        Utils.share(url: url, parentViewController: parentViewController, sourceItem: sourceItem)
    }

    public static func share(text: String, parentViewController: UIViewController, sourceItem: UIBarButtonItem) {
        guard let textData = text.data(using: .utf8) else { return }

        // UTF-8 byte order mark, commonly seen in text files. See [List Of file signatures](https://en.wikipedia.org/wiki/List_of_file_signatures)
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(textData)

        let tempLogfileURL = FileManager.default.temporaryDirectory.appendingPathComponent("deltachat-log.txt")
        try? FileManager.default.removeItem(at: tempLogfileURL)
        try? data.write(to: tempLogfileURL)
        
        Utils.share(url: tempLogfileURL, parentViewController: parentViewController, sourceItem: sourceItem)
    }

    public static func share(url: URL, parentViewController: UIViewController, sourceItem: UIBarButtonItem) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.barButtonItem = sourceItem
        parentViewController.present(activityVC, animated: true, completion: nil)
    }

    public static func share(text: String, parentViewController: UIViewController, sourceView: UIView) {
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = sourceView // iPad crashes without a source
        parentViewController.present(activityVC, animated: true, completion: nil)
    }

    public static func share(url: URL, parentViewController: UIViewController, sourceView: UIView) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = sourceView // iPad crashes without a source
        parentViewController.present(activityVC, animated: true, completion: nil)
    }

    public static func authenticateDeviceOwner(reason: String, callback: @escaping () -> Void) {
        let localAuthenticationContext = LAContext()
        var error: NSError?
        if localAuthenticationContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            localAuthenticationContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    if success {
                        callback()
                    } else {
                        logger.info("local authentication aborted: \(String(describing: error))")
                    }
                }
            }
        } else {
            logger.info("local authentication unavailable: \(String(describing: error))")
            callback()
        }
    }
}

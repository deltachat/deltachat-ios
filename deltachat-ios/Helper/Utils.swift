import Foundation
import UIKit
import DcCore

struct Utils {
    private static let inviteDomain = "i.delta.chat"

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
        if #available(iOS 13.0, *) {
            let window = UIApplication.shared.windows.first
            return window?.safeAreaInsets.bottom ?? 0
        }
        // iOS 11 and 12
        let window = UIApplication.shared.keyWindow
        return window?.safeAreaInsets.bottom ?? 0
    }

    public static func getInviteLink(context: DcContext, chatId: Int) -> String? {
        // convert `OPENPGP4FPR:FPR#a=ADDR&n=NAME&...` to `https://i.delta.chat/#FPR&a=ADDR&n=NAME&...`
        if var data = context.getSecurejoinQr(chatId: chatId), let range = data.range(of: "#") {
            data.replaceSubrange(range, with: "&")
            if let range = data.range(of: "OPENPGP4FPR:") {
                data.replaceSubrange(range, with: "https://" + inviteDomain + "/#")
                return data
            }
        }
        return nil
    }

    public static func share(message: DcMsg, parentViewController: UIViewController, sourceView: UIView? = nil, sourceItem: UIBarButtonItem? = nil) {
        guard let fileURL = message.fileURL else { return }
        let objectsToShare: [Any]
        if message.type == DC_MSG_WEBXDC {
            let dict = message.getWebxdcInfoDict()
            let previewImage = message.getWebxdcPreviewImage()
            let previewText = dict["name"] as? String ?? fileURL.lastPathComponent
            objectsToShare = [WebxdcItemSource(title: previewText,
                                               previewImage: previewImage,
                                               url: fileURL)]
        } else {
            objectsToShare = [fileURL]
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
        guard let data = text.data(using: .utf8) else { return }

        let tempLogfileURL = FileManager.default.localDocumentsDir.appendingPathComponent("log.txt")
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
}

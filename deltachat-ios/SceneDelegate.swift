import DcCore
import Intents
import UIKit

class SceneDelegate: UIResponder, UISceneDelegate, UNUserNotificationCenterDelegate {
    weak var appDelegate: AppDelegate?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.window?.windowScene = scene as? UIWindowScene
        appDelegate?.callWindow?.windowScene = scene as? UIWindowScene
    }


    func sceneWillEnterForeground(_ scene: UIScene) {
        logger.info("➡️ sceneWillEnterForeground")
        UserDefaults.setMainIoRunning()
        DcAccounts.shared.startIo()

        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            if let reachability = appDelegate?.reachability {
                if reachability.connection != .unavailable {
                    DcAccounts.shared.maybeNetwork()
                }
            }

            AppDelegate.emitMsgsChangedIfShareExtensionWasUsed()
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        logger.info("➡️ sceneDidBecomeActive")
        UserDefaults.setMainIoRunning()
        NotificationManager.updateBadgeCounters()
        if DcAccounts.shared.getSelected().isConfigured() {
            // This supports the case that app clips stay installed and
            // keep handling i.delta.chat links instead of the main app which
            // shouldn't happen but would be pretty bad so better safe than sorry
            appDelegate?.handleAppClipInviteLink()
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        logger.info("⬅️ sceneWillResignActive")
        appDelegate?.registerBackgroundTask()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        logger.info("⬅️ sceneDidEnterBackground")
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let incomingURL = userActivity.webpageURL,
           let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true),
           let host = components.host {
            logger.info("➡️ open univeral link url")

            if host == Utils.inviteDomain {
                appDelegate?.appCoordinator.handleQRCode(incomingURL.absoluteString)
            }
        } else if userActivity.interaction?.intent is INStartAudioCallIntent {
            logger.info("➡️ INStartAudioCallIntent")
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        logger.info("➡️ open url")

        guard let url = URLContexts.first?.url else { return }

        switch url.scheme?.lowercased() {
        case "dcaccount", "dclogin",
             "https" where url.host == Utils.inviteDomain:
            appDelegate?.appCoordinator.handleQRCode(url.absoluteString)
        case "openpgp4fpr":
            // Hack to format url properly
            let urlString = url.absoluteString
                .replacingOccurrences(of: "openpgp4fpr", with: "OPENPGP4FPR", options: .literal, range: nil)
                .replacingOccurrences(of: "%23", with: "#", options: .literal, range: nil)
            appDelegate?.appCoordinator.handleQRCode(urlString)
        case "mailto":
            appDelegate?.appCoordinator.handleMailtoURL(url)
        case "chat.delta.deeplink":
            appDelegate?.appCoordinator.handleDeepLinkURL(url)
        default:
            break
        }
    }
}

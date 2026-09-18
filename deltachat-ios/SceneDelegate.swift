import DcCore
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
}

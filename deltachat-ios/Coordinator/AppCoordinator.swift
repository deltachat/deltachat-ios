import UIKit
import Photos
import MobileCoreServices
import DcCore

// MARK: - AppCoordinator
class AppCoordinator {

    private let window: UIWindow
    private let dcAccounts: DcAccounts
    private let qrTab = 0
    public  let chatsTab = 1
    private let settingsTab = 2

    private let appStateRestorer = AppStateRestorer.shared

    // MARK: - login view handling
    private lazy var loginNavController: UINavigationController = {
        let nav = UINavigationController() // we change the root, therefore do not set on implicit creation
        return nav
    }()

    // MARK: - tabbar view handling
    lazy var tabBarController: UITabBarController = {
        let qrNavController = createQrNavigationController()
        let chatsNavController = createChatsNavigationController()
        let settingsNavController = createSettingsNavigationController()
        let tabBarController = UITabBarController()
        tabBarController.delegate = appStateRestorer
        tabBarController.viewControllers = [qrNavController, chatsNavController, settingsNavController]
        tabBarController.tabBar.tintColor = DcColors.primary
        return tabBarController
    }()

    private func createQrNavigationController() -> UINavigationController {
        let root = QrPageController(dcAccounts: dcAccounts)
        let nav = UINavigationController(rootViewController: root)
        let settingsImage = UIImage(named: "qr_code")
        nav.tabBarItem = UITabBarItem(title: String.localized("qr_code"), image: settingsImage, tag: qrTab)
        return nav
    }

    private func createChatsNavigationController() -> UINavigationController {
        let root = ChatListController(dcContext: dcAccounts.getSelected(), isArchive: false)
        let nav = UINavigationController(rootViewController: root)
        let settingsImage = UIImage(named: "ic_chat")
        nav.tabBarItem = UITabBarItem(title: String.localized("pref_chats"), image: settingsImage, tag: chatsTab)
        return nav
    }

    private func createSettingsNavigationController() -> UINavigationController {
        let root = SettingsViewController(dcAccounts: dcAccounts)
        let nav = UINavigationController(rootViewController: root)
        let settingsImage = UIImage(named: "settings")
        nav.tabBarItem = UITabBarItem(title: String.localized("menu_settings"), image: settingsImage, tag: settingsTab)
        return nav
    }

    // MARK: - misc
    init(window: UIWindow, dcAccounts: DcAccounts) {
        self.window = window
        self.dcAccounts = dcAccounts
        let dcContext = dcAccounts.getSelected()
        initializeRootController()

        let lastActiveTab = appStateRestorer.restoreLastActiveTab()
        if lastActiveTab == -1 {
            // no stored tab
            showTab(index: chatsTab)
        } else {
            showTab(index: lastActiveTab)
            if let lastActiveChatId = appStateRestorer.restoreLastActiveChatId(), lastActiveTab == chatsTab {
                // as getChat() returns an empty object for invalid chatId,
                // check that the returned object is actually set up.
                if dcContext.getChat(chatId: lastActiveChatId).id == lastActiveChatId {
                    showChat(chatId: lastActiveChatId, animated: false)
                }
            }
        }
    }

    func showTab(index: Int) {
        tabBarController.selectedIndex = index
    }

    func showArchivedChats() {
        showTab(index: chatsTab)

        if let rootController = self.tabBarController.selectedViewController as? UINavigationController,
           let chatListController = rootController.viewControllers.first as? ChatListController {
            rootController.popToRootViewController(animated: false)
            chatListController.showArchive(animated: false)
        }
    }

    func isShowingChat(chatId: Int) -> Bool {
        if let rootController = self.tabBarController.selectedViewController as? UINavigationController,
           let chatViewController = rootController.viewControllers.last as? ChatViewController,
           chatViewController.chatId == chatId {
            return true
        }
        return false
    }

    func showChat(chatId: Int, msgId: Int? = nil, openHighlightedMsg: Bool = false, animated: Bool = true, clearViewControllerStack: Bool = false) {
        showTab(index: chatsTab)

        if let rootController = self.tabBarController.selectedViewController as? UINavigationController {
            if clearViewControllerStack {
                rootController.popToRootViewController(animated: false)
            }
            if let controller = rootController.viewControllers.first as? ChatListController {
                controller.showChat(chatId: chatId, highlightedMsg: msgId, openHighlightedMsg: openHighlightedMsg, animated: animated)
            }
        }
    }

    func handleDeepLinkURL(_ url: URL) -> Bool {
        guard let parameters = url.queryParameters else {
            logger.error("Missing parameters in URL \(url)")
            return false
        }

        let accountId = Int(parameters["accountId"] ?? "-1") ?? -1
        let chatId = Int(parameters["chatId"] ?? "-1") ?? -1
        let messageId = Int(parameters["msgId"] ?? "-1") ?? -1

        if !"\(url)".starts(with: "chat.delta.deeplink://webxdc?") ||
           messageId == -1 ||
           chatId == -1 ||
           accountId == -1 {
            return false
        }

        if dcAccounts.getSelected().id != accountId {
            if !dcAccounts.select(id: accountId) {
                return false
            }
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return false }
            appDelegate.reloadDcContext()
        }

        let dcContext = dcAccounts.getSelected()
        let dcMsg = dcContext.getMessage(id: messageId)
        if dcMsg.type == DC_MSG_WEBXDC {
            showChat(chatId: chatId, msgId: messageId, openHighlightedMsg: true, animated: false, clearViewControllerStack: true)
            return true
        }
        return false
    }

    func handleMailtoURL(_ url: URL) -> Bool {
        if RelayHelper.shared.parseMailtoUrl(url) {
            showTab(index: chatsTab)
            if let rootController = self.tabBarController.selectedViewController as? UINavigationController {
                rootController.popToRootViewController(animated: false)
                if let controller = rootController.viewControllers.first as? ChatListController {
                    controller.handleMailto(askToChat: RelayHelper.shared.askToChatWithMailto)
                    return true
                }
            }
        } else {
            logger.warning("Could not parse mailto: URL")
        }
        RelayHelper.shared.finishMailto()
        return false
    }

    func handleQRCode(_ code: String) {
        if code.lowercased().starts(with: "dcaccount:") {
            presentWelcomeController(accountCode: code)
        } else {
            showTab(index: qrTab)
            if let navController = self.tabBarController.selectedViewController as? UINavigationController,
               let topViewController = navController.topViewController,
                let qrPageController = topViewController as? QrPageController {
                qrPageController.handleQrCode(code)
            }
        }
    }

    func initializeRootController() {
        if dcAccounts.getSelected().isConfigured() {
            presentTabBarController()
        } else {
            presentWelcomeController()
        }

        // make sure, we use the same font in all titles,
        // here and in the custom chatlist title
        // (according to https://learnui.design/blog/ios-font-size-guidelines.html )
        // (it would be a bit nicer, if we would query the system font and pass it to chatlist, but well :)
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
    }

    func presentWelcomeController(accountCode: String? = nil) {
        loginNavController.setViewControllers([WelcomeViewController(dcAccounts: dcAccounts, accountCode: accountCode)], animated: true)
        window.rootViewController = loginNavController
        window.makeKeyAndVisible()

        // the applicationIconBadgeNumber is remembered by the system even on reinstalls (just tested on ios 13.3.1),
        // to avoid appearing an old number of a previous installation, we reset the counter manually.
        // but even when this changes in ios, we need the reset as we allow account-deletion also in-app.
        NotificationManager.updateApplicationIconBadge(dcContext: dcAccounts.getSelected(), reset: true)
    }

    func presentTabBarController() {
        window.rootViewController = tabBarController
        showTab(index: chatsTab)
        window.makeKeyAndVisible()
    }

    func popTabsToRootViewControllers() {
        self.tabBarController.viewControllers?.forEach { controller in
            if let navController = controller as? UINavigationController {
                navController.popToRootViewController(animated: false)
            }
        }
    }

    func resetTabBarRootViewControllers() {
        self.tabBarController.setViewControllers([createQrNavigationController(),
                                                  createChatsNavigationController(),
                                                  createSettingsNavigationController()], animated: false)
        presentTabBarController()
    }
}

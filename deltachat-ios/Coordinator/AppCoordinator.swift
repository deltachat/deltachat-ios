import UIKit
import Photos
import MobileCoreServices
import DcCore

// MARK: - AppCoordinator
class AppCoordinator {

    private let window: UIWindow
    private let dcContext: DcContext
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
    private lazy var tabBarController: UITabBarController = {
        let tabBarController = UITabBarController()
        tabBarController.delegate = appStateRestorer
        tabBarController.viewControllers = [qrNavController, chatsNavController, settingsNavController]
        tabBarController.tabBar.tintColor = DcColors.primary
        return tabBarController
    }()

    private lazy var qrNavController: UINavigationController = {
        let root = QrPageController(dcContext: dcContext)
        let nav = UINavigationController(rootViewController: root)
        let settingsImage = UIImage(named: "qr_code")
        nav.tabBarItem = UITabBarItem(title: String.localized("qr_code"), image: settingsImage, tag: qrTab)
        return nav
    }()

    private lazy var chatsNavController: UINavigationController = {
        let viewModel = ChatListViewModel(dcContext: dcContext, isArchive: false)
        let root = ChatListController(dcContext: dcContext, viewModel: viewModel)
        let nav = UINavigationController(rootViewController: root)
        let settingsImage = UIImage(named: "ic_chat")
        nav.tabBarItem = UITabBarItem(title: String.localized("pref_chats"), image: settingsImage, tag: chatsTab)
        return nav
    }()

    private lazy var settingsNavController: UINavigationController = {
        let root = SettingsViewController(dcContext: dcContext)
        let nav = UINavigationController(rootViewController: root)
        let settingsImage = UIImage(named: "settings")
        nav.tabBarItem = UITabBarItem(title: String.localized("menu_settings"), image: settingsImage, tag: settingsTab)
        return nav
    }()

    // MARK: - misc
    init(window: UIWindow, dcContext: DcContext) {
        self.window = window
        self.dcContext = dcContext

        if dcContext.isConfigured() {
            presentTabBarController()
        } else {
            presentWelcomeController()
        }

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

    func showChat(chatId: Int, msgId: Int? = nil, animated: Bool = true) {
        showTab(index: chatsTab)
        if let rootController = self.chatsNavController.viewControllers.first as? ChatListController {
            rootController.showChat(chatId: chatId, highlightedMsg: msgId, animated: animated)
        }
    }

    func handleQRCode(_ code: String) {
        showTab(index: qrTab)
        if let topViewController = qrNavController.topViewController,
            let qrPageController = topViewController as? QrPageController {
            qrPageController.handleQrCode(code)
        }
    }

    func presentWelcomeController() {
        loginNavController.setViewControllers([WelcomeViewController(dcContext: dcContext)], animated: true)
        window.rootViewController = loginNavController
        window.makeKeyAndVisible()

        // the applicationIconBadgeNumber is remembered by the system even on reinstalls (just tested on ios 13.3.1),
        // to avoid appearing an old number of a previous installation, we reset the counter manually.
        // but even when this changes in ios, we need the reset as we allow account-deletion also in-app.
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    func presentTabBarController() {
        window.rootViewController = tabBarController
        showTab(index: chatsTab)
        window.makeKeyAndVisible()
    }

    func popTabsToRootViewControllers() {
        qrNavController.popToRootViewController(animated: false)
        chatsNavController.popToRootViewController(animated: false)
        settingsNavController.popToRootViewController(animated: false)
    }
}

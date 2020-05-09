import UIKit
import KK_ALCameraViewController
import Photos
import MobileCoreServices
import DcCore

// MARK: - AppCoordinator
class AppCoordinator: NSObject, Coordinator {

    private let window: UIWindow
    private let dcContext: DcContext
    private let qrTab = 0
    public  let chatsTab = 1
    private let settingsTab = 2

    private let appStateRestorer = AppStateRestorer.shared

    private lazy var tabBarController: UITabBarController = {
        let tabBarController = UITabBarController()
        tabBarController.delegate = appStateRestorer
        tabBarController.viewControllers = [qrPageController, chatListController, settingsController]
        tabBarController.tabBar.tintColor = DcColors.primary
        return tabBarController
    }()

    private lazy var loginController: UINavigationController = {
        let accountSetupController = AccountSetupController(dcContext: dcContext, editView: false)
        let nav = UINavigationController(rootViewController: accountSetupController)
        accountSetupController.onLoginSuccess = {
            [unowned self] in
            self.loginController.dismiss(animated: true) {
                self.presentTabBarController()
            }
        }
        return nav
    }()

    // MARK: viewControllers

    private lazy var qrPageController: UINavigationController = {
        let root = QrPageController(dcContext: dcContext)
        let nav = UINavigationController(rootViewController: root)
        let settingsImage = UIImage(named: "qr_code")
        nav.tabBarItem = UITabBarItem(title: String.localized("qr_code"), image: settingsImage, tag: qrTab)
        return nav
    }()

    private lazy var chatListController: UINavigationController = {
        let viewModel = ChatListViewModel(dcContext: dcContext, isArchive: false)
        let root = ChatListController(dcContext: dcContext, viewModel: viewModel)
        let nav = UINavigationController(rootViewController: root)
        let settingsImage = UIImage(named: "ic_chat")
        nav.tabBarItem = UITabBarItem(title: String.localized("pref_chats"), image: settingsImage, tag: chatsTab)
        return nav
    }()

    private lazy var settingsController: UINavigationController = {
        let root = SettingsViewController(dcContext: dcContext)
        let nav = UINavigationController(rootViewController: root)
        let settingsImage = UIImage(named: "settings")
        nav.tabBarItem = UITabBarItem(title: String.localized("menu_settings"), image: settingsImage, tag: settingsTab)
        return nav
    }()

    private var welcomeController: WelcomeViewController?

    init(window: UIWindow, dcContext: DcContext) {
        self.window = window
        self.dcContext = dcContext
        super.init()

        if dcContext.isConfigured() {
            presentTabBarController()
        } else {
            presentWelcomeController()
        }
    }

    public func start() {
        let lastActiveTab = appStateRestorer.restoreLastActiveTab()
        if lastActiveTab == -1 {
            // no stored tab
            showTab(index: chatsTab)
        } else {
            showTab(index: lastActiveTab)
            if let lastActiveChatId = appStateRestorer.restoreLastActiveChatId(), lastActiveTab == 1 {
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

    func showChat(chatId: Int, animated: Bool = true) {
        showTab(index: chatsTab)
        if let rootController = self.chatListController.viewControllers.first as? ChatListController {
            rootController.showChat(chatId: chatId)
        }
    }

    func handleQRCode(_ code: String) {
        showTab(index: qrTab)
        if let topViewController = qrPageController.topViewController,
            let qrPageController = topViewController as? QrPageController {
            qrPageController.handleQrCode(code)
        }
    }

    func presentWelcomeController() {
        // the applicationIconBadgeNumber is remembered by the system even on reinstalls (just tested on ios 13.3.1),
        // to avoid appearing an old number of a previous installation, we reset the counter manually.
        // but even when this changes in ios, we need the reset as we allow account-deletion also in-app.
        UIApplication.shared.applicationIconBadgeNumber = 0

        let wc = WelcomeViewController(dcContext: dcContext)
        self.welcomeController = wc
        window.rootViewController = wc
        window.makeKeyAndVisible()
    }

    func presentTabBarController() {
        window.rootViewController = tabBarController
        welcomeController = nil
        window.makeKeyAndVisible()
        showTab(index: chatsTab)
    }

    func presentLogin() {
        // add cancel button item to accountSetupController
        if let accountSetupController = loginController.topViewController as? AccountSetupController {
            accountSetupController.navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: String.localized("cancel"),
                style: .done,
                target: self, action: #selector(loginCancelButtonPressed)
            )
            accountSetupController.onLoginSuccess = handleLoginSuccess
        }
        loginController.modalPresentationStyle = .fullScreen
        welcomeController?.present(loginController, animated: true, completion: nil)
    }

    @objc private func loginCancelButtonPressed(_ sender: UIBarButtonItem) {
        loginController.dismiss(animated: true, completion: nil)
    }

    private func handleLoginSuccess() {
        presentTabBarController()
    }

    func handleQRAccountCreationSuccess() {
        let profileInfoController = ProfileInfoViewController(context: dcContext)
        let profileInfoNav = UINavigationController(rootViewController: profileInfoController)
        profileInfoNav.modalPresentationStyle = .fullScreen
        profileInfoController.onClose = handleLoginSuccess
        welcomeController?.present(profileInfoNav, animated: true, completion: nil)
    }
}

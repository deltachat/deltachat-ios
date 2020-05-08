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

    private var childCoordinators: [Coordinator] = []

    private lazy var tabBarController: UITabBarController = {
        let tabBarController = UITabBarController()
        tabBarController.delegate = appStateRestorer
        tabBarController.viewControllers = [qrPageController, chatListController, settingsController]
        tabBarController.tabBar.tintColor = DcColors.primary
        return tabBarController
    }()

    private lazy var loginController: UIViewController = {
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
        let pageController = QrPageController(dcContext: dcContext)
        let nav = UINavigationController(rootViewController: pageController)
        let settingsImage = UIImage(named: "qr_code")
        nav.tabBarItem = UITabBarItem(title: String.localized("qr_code"), image: settingsImage, tag: qrTab)
        return nav
    }()

    private lazy var chatListController: UIViewController = {
        let viewModel = ChatListViewModel(dcContext: dcContext, isArchive: false)
        let controller = ChatListController(dcContext: dcContext, viewModel: viewModel)
        let nav = UINavigationController(rootViewController: controller)
        let settingsImage = UIImage(named: "ic_chat")
        nav.tabBarItem = UITabBarItem(title: String.localized("pref_chats"), image: settingsImage, tag: chatsTab)
        return nav
    }()

    private lazy var settingsController: UIViewController = {
        let controller = SettingsViewController(dcContext: dcContext)
        let nav = UINavigationController(rootViewController: controller)
        let settingsImage = UIImage(named: "settings")
        nav.tabBarItem = UITabBarItem(title: String.localized("menu_settings"), image: settingsImage, tag: settingsTab)
        return nav
    }()


    private var welcomeController: WelcomeViewController?
    private var profileInfoNavigationController: UINavigationController?

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
        guard let navController = self.chatListController as? UINavigationController else {
            assertionFailure("huh? why no nav controller?")
            return
        }

        if let rootController = navController.viewControllers.first as? ChatListController {
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

        let wc = makeWelcomeController()
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

    private func makeWelcomeController() -> WelcomeViewController {
        let welcomeController = WelcomeViewController(dcContext: dcContext)
        welcomeController.coordinator = self
        return welcomeController
    }
}

// MARK: - WelcomeCoordinator
extension AppCoordinator: WelcomeCoordinator {

    func presentLogin() {
        // add cancel button item to accountSetupController
        if let nav = loginController as? UINavigationController, let loginController = nav.topViewController as? AccountSetupController {
            loginController.navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: String.localized("cancel"),
                style: .done,
                target: self, action: #selector(cancelButtonPressed(_:))
            )
            loginController.onLoginSuccess = handleLoginSuccess
        }
        loginController.modalPresentationStyle = .fullScreen
        welcomeController?.present(loginController, animated: true, completion: nil)
    }

    func handleQRAccountCreationSuccess() {
        let profileInfoController = ProfileInfoViewController(context: dcContext)
        let profileInfoNav = UINavigationController(rootViewController: profileInfoController)
        profileInfoNav.modalPresentationStyle = .fullScreen
        let coordinator = EditSettingsCoordinator(dcContext: dcContext, navigationController: profileInfoNav)
        profileInfoController.coordinator = coordinator
        childCoordinators.append(coordinator)
        profileInfoController.onClose = handleLoginSuccess
        welcomeController?.present(profileInfoNav, animated: true, completion: nil)
    }

    func handleLoginSuccess() {
        presentTabBarController()
    }

    @objc private func cancelButtonPressed(_ sender: UIBarButtonItem) {
        loginController.dismiss(animated: true, completion: nil)
    }
}

// since mailbox and chatView -tab both use ChatViewController we want to be able to assign different functionality via coordinators -> therefore we override unneeded functions such as showChatDetail -> maybe find better solution in longterm
class MailboxCoordinator: ChatViewCoordinator {

    init(dcContext: DcContext, navigationController: UINavigationController) {
        super.init(dcContext: dcContext, navigationController: navigationController, chatId: -1)
    }

    override func showChatDetail(chatId _: Int) {
        // ignore for now
    }

    override func showCameraViewController(delegate: MediaPickerDelegate) {
        // ignore
    }

    override func showChat(chatId: Int) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            navigationController.popToRootViewController(animated: false)
            appDelegate.appCoordinator.showChat(chatId: chatId)
        }
    }
}

// MARK: - EditSettingsCoordinator
class EditSettingsCoordinator: Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController
    let mediaPicker: MediaPicker

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.navigationController = navigationController
        self.mediaPicker = MediaPicker(navigationController: navigationController)
    }

    func showPhotoPicker(delegate: MediaPickerDelegate) {
        mediaPicker.showPhotoGallery(delegate: delegate)
    }

    func showCamera(delegate: MediaPickerDelegate) {
        mediaPicker.showCamera(delegate: delegate)
    }
}

// MARK: - ChatViewCoordinator
class ChatViewCoordinator: NSObject, Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController
    let chatId: Int
    var chatViewController: ChatViewController!

    var childCoordinators: [Coordinator] = []
    let mediaPicker: MediaPicker

    init(dcContext: DcContext, navigationController: UINavigationController, chatId: Int) {
        self.dcContext = dcContext
        self.navigationController = navigationController
        self.chatId = chatId
        self.mediaPicker = MediaPicker(navigationController: self.navigationController)
    }

    func navigateBack() {
        navigationController.popViewController(animated: true)
    }

    func showChatDetail(chatId: Int) {
        let chat = dcContext.getChat(chatId: chatId)
        switch chat.chatType {
        case .SINGLE:
            if let contactId = chat.contactIds.first {
                let viewModel = ContactDetailViewModel(contactId: contactId, chatId: chatId, context: dcContext)
                let contactDetailController = ContactDetailViewController(viewModel: viewModel)
                navigationController.pushViewController(contactDetailController, animated: true)
            }
        case .GROUP, .VERIFIEDGROUP:
            let groupChatDetailViewController = GroupChatDetailViewController(chatId: chatId, dcContext: dcContext)
            navigationController.pushViewController(groupChatDetailViewController, animated: true)
        }
    }

    func showContactDetail(of contactId: Int, in chatOfType: ChatType, chatId: Int?) {
        let viewModel = ContactDetailViewModel(contactId: contactId, chatId: chatId, context: dcContext )
        let contactDetailController = ContactDetailViewController(viewModel: viewModel)
        navigationController.pushViewController(contactDetailController, animated: true)
    }

    func showChat(chatId: Int) {
        let chatViewController = ChatViewController(dcContext: dcContext, chatId: chatId)
        let coordinator = ChatViewCoordinator(dcContext: dcContext, navigationController: navigationController, chatId: chatId)
        childCoordinators.append(coordinator)
        chatViewController.coordinator = coordinator
        navigationController.popToRootViewController(animated: false)
        navigationController.pushViewController(chatViewController, animated: true)
    }

    func showDocumentLibrary(delegate: MediaPickerDelegate) {
        mediaPicker.showDocumentLibrary(delegate: delegate)
    }

    func showVoiceMessageRecorder(delegate: MediaPickerDelegate) {
        mediaPicker.showVoiceRecorder(delegate: delegate)
    }

    func showCameraViewController(delegate: MediaPickerDelegate) {
        mediaPicker.showCamera(delegate: delegate, allowCropping: false)
    }

    func showPhotoVideoLibrary(delegate: MediaPickerDelegate) {
        mediaPicker.showPhotoVideoLibrary(delegate: delegate)
    }

    func showMediaGallery(currentIndex: Int, mediaUrls urls: [URL]) {
        let betterPreviewController = PreviewController(currentIndex: currentIndex, urls: urls)
        let nav = UINavigationController(rootViewController: betterPreviewController)
        nav.modalPresentationStyle = .fullScreen
        navigationController.present(nav, animated: true)
    }
}

/*
 boilerplate - I tend to remove that interface (cyberta)
 */


protocol WelcomeCoordinator: class {
    func presentLogin()
    func handleLoginSuccess()
    func handleQRAccountCreationSuccess()
}

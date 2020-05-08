import UIKit
import KK_ALCameraViewController
import Photos
import MobileCoreServices
import DcCore
import DBDebugToolkit

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
        let coordinator = AccountSetupCoordinator(dcContext: dcContext, navigationController: nav)
        coordinator.onLoginSuccess = {
            [unowned self] in
            self.loginController.dismiss(animated: true) {
                self.presentTabBarController()
            }
        }
        childCoordinators.append(coordinator)
        accountSetupController.coordinator = coordinator
        return nav
    }()

    // MARK: viewControllers

    private lazy var qrPageController: UINavigationController = {
        let pageController = QrPageController(dcContext: dcContext)
        let nav = UINavigationController(rootViewController: pageController)
        let coordinator = QrViewCoordinator(navigationController: nav)
        self.childCoordinators.append(coordinator)
        pageController.coordinator = coordinator
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
        let coordinator = ChatListCoordinator(dcContext: dcContext, navigationController: nav)
        self.childCoordinators.append(coordinator)
        controller.coordinator = coordinator
        return nav
    }()

    private lazy var settingsController: UIViewController = {
        let controller = SettingsViewController(dcContext: dcContext)
        let nav = UINavigationController(rootViewController: controller)
        let settingsImage = UIImage(named: "settings")
        nav.tabBarItem = UITabBarItem(title: String.localized("menu_settings"), image: settingsImage, tag: settingsTab)
        let coordinator = SettingsCoordinator(dcContext: dcContext, navigationController: nav)
        self.childCoordinators.append(coordinator)
        controller.coordinator = coordinator
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
            rootController.coordinator?.showChat(chatId: chatId)
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
            loginController.coordinator?.onLoginSuccess = handleLoginSuccess
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

class QrViewCoordinator: Coordinator {
    var navigationController: UINavigationController
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func showChats() {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.appCoordinator.showTab(index: appDelegate.appCoordinator.chatsTab)
        }
    }

    func showChat(chatId: Int) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.appCoordinator.showChat(chatId: chatId)
        }
    }
}

class ChatListCoordinator: Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController

    var childCoordinators: [Coordinator] = []

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.navigationController = navigationController
    }

    func showNewChatController() {
        let newChatVC = NewChatViewController(dcContext: dcContext)
        let coordinator = NewChatCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        newChatVC.coordinator = coordinator
        navigationController.pushViewController(newChatVC, animated: true)
    }

    func showChat(chatId: Int) {
        let chatVC = ChatViewController(dcContext: dcContext, chatId: chatId)
        let coordinator = ChatViewCoordinator(dcContext: dcContext, navigationController: navigationController, chatId: chatId)
        childCoordinators.append(coordinator)
        chatVC.coordinator = coordinator
        navigationController.pushViewController(chatVC, animated: true)
    }

    func showArchive() {
        let viewModel = ChatListViewModel(dcContext: dcContext, isArchive: true)
        let controller = ChatListController(dcContext: dcContext, viewModel: viewModel)
        let coordinator = ChatListCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        controller.coordinator = coordinator
        navigationController.pushViewController(controller, animated: true)
    }

    func showNewChat(contactId: Int) {
        let chatId = dcContext.createChatByContactId(contactId: contactId)
        showChat(chatId: Int(chatId))
    }
}

// MARK: - SettingsCoordinator
class SettingsCoordinator: Coordinator {
    let dcContext: DcContext
    let navigationController: UINavigationController

    var childCoordinators: [Coordinator] = []

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.navigationController = navigationController
    }

    func showEditSettingsController() {
        let editController = EditSettingsController(dcContext: dcContext)
        let coordinator = EditSettingsCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        editController.coordinator = coordinator
        navigationController.pushViewController(editController, animated: true)
    }

    func showClassicMail() {
        let settingsClassicViewController = SettingsClassicViewController(dcContext: dcContext)
        navigationController.pushViewController(settingsClassicViewController, animated: true)
    }

    func showBlockedContacts() {
        let blockedContactsController = BlockedContactsViewController()
        navigationController.pushViewController(blockedContactsController, animated: true)
    }

    func showAutodelOptions() {
        let settingsAutodelOverviewController = SettingsAutodelOverviewController(dcContext: dcContext)
        navigationController.pushViewController(settingsAutodelOverviewController, animated: true)
    }

    func showContactRequests() {
        let deaddropViewController = MailboxViewController(dcContext: dcContext, chatId: Int(DC_CHAT_ID_DEADDROP))
        let deaddropCoordinator = MailboxCoordinator(dcContext: dcContext, navigationController: navigationController)
        deaddropViewController.coordinator = deaddropCoordinator
        childCoordinators.append(deaddropCoordinator)
        navigationController.pushViewController(deaddropViewController, animated: true)
    }

    func showHelp() {
        let helpViewController = HelpViewController()
        navigationController.pushViewController(helpViewController, animated: true)
    }

    func showDebugToolkit() {
        DBDebugToolkit.setup(with: [])  // emtpy array will override default device shake trigger
        DBDebugToolkit.setupCrashReporting()
        let info: [DBCustomVariable] = dcContext.getInfo().map { kv in
            let value = kv.count > 1 ? kv[1] : ""
            return DBCustomVariable(name: kv[0], value: value)
        }
        DBDebugToolkit.add(info)
        DBDebugToolkit.showMenu()
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

// MARK: - AccountSetupCoordinator
class AccountSetupCoordinator: Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController
    var onLoginSuccess: (() -> Void)?

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.navigationController = navigationController
    }

    func showCertCheckOptions() {
        let certificateCheckController = CertificateCheckController(dcContext: dcContext, sectionTitle: String.localized("login_certificate_checks"))
        navigationController.pushViewController(certificateCheckController, animated: true)
    }

    func showImapSecurityOptions() {
        let securitySettingsController = SecuritySettingsController(dcContext: dcContext, title: String.localized("login_imap_security"),
                                                                      type: SecurityType.IMAPSecurity)
        navigationController.pushViewController(securitySettingsController, animated: true)
    }

    func showSmptpSecurityOptions() {
        let securitySettingsController = SecuritySettingsController(dcContext: dcContext,
                                                                    title: String.localized("login_imap_security"),
                                                                    type: SecurityType.SMTPSecurity)
        navigationController.pushViewController(securitySettingsController, animated: true)
    }

    func openProviderInfo(provider: DcProvider) {
        guard let url = URL(string: provider.getOverviewPage) else { return }
        UIApplication.shared.open(url)
    }

    func navigateBack() {
        navigationController.popViewController(animated: true)
    }
}

// MARK: - NewChatCoordinator
class NewChatCoordinator: Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController

    private var childCoordinators: [Coordinator] = []

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.navigationController = navigationController
    }

    func showNewGroupController(isVerified: Bool) {
        let newGroupController = NewGroupController(dcContext: dcContext, isVerified: isVerified)
        navigationController.pushViewController(newGroupController, animated: true)
    }

    func showNewContactController() {
        let newContactController = NewContactController(dcContext: dcContext)
        navigationController.pushViewController(newContactController, animated: true)
    }

    func showNewChat(contactId: Int) {
        let chatId = dcContext.createChatByContactId(contactId: contactId)
        showChat(chatId: Int(chatId))
    }

    func showChat(chatId: Int) {
        let chatViewController = ChatViewController(dcContext: dcContext, chatId: chatId)
        let coordinator = ChatViewCoordinator(dcContext: dcContext, navigationController: navigationController, chatId: chatId)
        childCoordinators.append(coordinator)
        chatViewController.coordinator = coordinator
        navigationController.pushViewController(chatViewController, animated: true)
        navigationController.viewControllers.remove(at: 1)
    }

    func showContactDetail(contactId: Int) {
        let viewModel = ContactDetailViewModel(contactId: contactId, chatId: nil, context: dcContext)
        let contactDetailController = ContactDetailViewController(viewModel: viewModel)
        navigationController.pushViewController(contactDetailController, animated: true)
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

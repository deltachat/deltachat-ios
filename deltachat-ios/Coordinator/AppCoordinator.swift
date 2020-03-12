import UIKit
import ALCameraViewController
import Photos
import MobileCoreServices

class AppCoordinator: NSObject, Coordinator {
    private let window: UIWindow
    private let dcContext: DcContext
    private let qrTab = 0
    private let chatsTab = 1
    private let settingsTab = 2

    private var childCoordinators: [Coordinator] = []

    private lazy var tabBarController: UITabBarController = {
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [qrController, chatListController, settingsController]
        tabBarController.tabBar.tintColor = DcColors.primary
        return tabBarController
    }()

    private lazy var loginController: UIViewController = {
        let accountSetupController = AccountSetupController(dcContext: dcContext, editView: false)
        let accountSetupNav = DcNavigationController(rootViewController: accountSetupController)
        let coordinator = AccountSetupCoordinator(dcContext: dcContext, navigationController: accountSetupNav)
        coordinator.onLoginSuccess = presentTabBarController
        childCoordinators.append(coordinator)
        accountSetupController.coordinator = coordinator
        return accountSetupNav
    }()

    // MARK: viewControllers

    private lazy var qrController: UIViewController = {
        let controller = QrViewController(dcContext: dcContext)
        let nav = DcNavigationController(rootViewController: controller)
        let settingsImage = UIImage(named: "qr_code")
        nav.tabBarItem = UITabBarItem(title: String.localized("qr_code"), image: settingsImage, tag: qrTab)
        let coordinator = QrViewCoordinator(navigationController: nav)
        self.childCoordinators.append(coordinator)
        controller.coordinator = coordinator
        return nav
    }()

    private lazy var chatListController: UIViewController = {
        let controller = ChatListController(dcContext: dcContext, showArchive: false)
        let nav = DcNavigationController(rootViewController: controller)
        let settingsImage = UIImage(named: "ic_chat")
        nav.tabBarItem = UITabBarItem(title: String.localized("pref_chats"), image: settingsImage, tag: chatsTab)
        let coordinator = ChatListCoordinator(dcContext: dcContext, navigationController: nav)
        self.childCoordinators.append(coordinator)
        controller.coordinator = coordinator
        return nav
    }()

    private lazy var settingsController: UIViewController = {
        let controller = SettingsViewController(dcContext: dcContext)
        let nav = DcNavigationController(rootViewController: controller)
        let settingsImage = UIImage(named: "settings")
        nav.tabBarItem = UITabBarItem(title: String.localized("menu_settings"), image: settingsImage, tag: settingsTab)
        let coordinator = SettingsCoordinator(dcContext: dcContext, navigationController: nav)
        self.childCoordinators.append(coordinator)
        controller.coordinator = coordinator
        return nav
    }()

    init(window: UIWindow, dcContext: DcContext) {
        self.window = window
        self.dcContext = dcContext
        super.init()

        if dcContext.isConfigured() {
            presentTabBarController()
        } else {
            presentLoginController()
        }
    }

    public func start() {
        print(tabBarController.selectedIndex)
        showTab(index: chatsTab)
    }

    func showTab(index: Int) {
        tabBarController.selectedIndex = index
    }

    func showChat(chatId: Int) {
        showTab(index: chatsTab)
        guard let navController = self.chatListController as? UINavigationController else {
            assertionFailure("huh? why no nav controller?")
            return
        }
        let chatVC = ChatViewController(dcContext: dcContext, chatId: chatId)
        let coordinator = ChatViewCoordinator(dcContext: dcContext, navigationController: navController, chatId: chatId)
        chatVC.coordinator = coordinator
        navController.pushViewController(chatVC, animated: true)
    }

    func handleQRCode(_ code: String) {
        showTab(index: qrTab)
        if let navController = qrController as? UINavigationController,
            let topViewController = navController.topViewController,
            let qrViewController = topViewController as? QrViewController {
            qrViewController.handleQrCode(code)
        }
    }

    func presentLoginController() {
        window.rootViewController = loginController
        window.makeKeyAndVisible()
    }

    func presentTabBarController() {
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        showTab(index: chatsTab)
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
        let controller = ChatListController(dcContext: dcContext, showArchive: true)
        let coordinator = ChatListCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        controller.coordinator = coordinator
        navigationController.pushViewController(controller, animated: true)
    }
}

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
}

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


class AccountSetupCoordinator: Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController
    var onLoginSuccess: (() -> Void)?

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.navigationController = navigationController
    }

    func showCertCheckOptions() {
        let certificateCheckController = CertificateCheckController(sectionTitle: String.localized("login_certificate_checks"))
        navigationController.pushViewController(certificateCheckController, animated: true)
    }

    func showImapSecurityOptions() {
        let securitySettingsController = SecuritySettingsController(title: String.localized("login_imap_security"),
                                                                      type: SecurityType.IMAPSecurity)
        navigationController.pushViewController(securitySettingsController, animated: true)
    }

    func showSmptpSecurityOptions() {
        let securitySettingsController = SecuritySettingsController(title: String.localized("login_imap_security"), type: SecurityType.SMTPSecurity)
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
        let coordinator = NewGroupCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        newGroupController.coordinator = coordinator
        navigationController.pushViewController(newGroupController, animated: true)
    }

    func showNewContactController() {
        let newContactController = NewContactController()
        let coordinator = EditContactCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        newContactController.coordinator = coordinator
        navigationController.pushViewController(newContactController, animated: true)
    }

    func showNewChat(contactId: Int) {
        let chatId = dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))
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
        let coordinator = ContactDetailCoordinator(dcContext: dcContext, chatId: nil, navigationController: navigationController)
        childCoordinators.append(coordinator)
        contactDetailController.coordinator = coordinator
        navigationController.pushViewController(contactDetailController, animated: true)
    }
    
}

class GroupChatDetailCoordinator: Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController
    let chatId: Int

    private var childCoordinators: [Coordinator] = []
    private var previewController: PreviewController?

    init(dcContext: DcContext, chatId: Int, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.chatId = chatId
        self.navigationController = navigationController
    }

    func showSingleChatEdit(contactId: Int) {
        let editContactController = EditContactController(contactIdForUpdate: contactId)
        let coordinator = EditContactCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        editContactController.coordinator = coordinator
        navigationController.pushViewController(editContactController, animated: true)
    }

    func showAddGroupMember(chatId: Int) {
        let groupMemberViewController = AddGroupMembersViewController(chatId: chatId)
        let coordinator = AddGroupMembersCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        groupMemberViewController.coordinator = coordinator
        navigationController.pushViewController(groupMemberViewController, animated: true)
    }

    func showQrCodeInvite(chatId: Int) {
        let qrInviteCodeController = QrInviteViewController(dcContext: dcContext, chatId: chatId)
        navigationController.pushViewController(qrInviteCodeController, animated: true)
    }

    func showGroupChatEdit(chat: DcChat) {
        let editGroupViewController = EditGroupViewController(chat: chat)
        let coordinator = EditGroupCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        editGroupViewController.coordinator = coordinator
        navigationController.pushViewController(editGroupViewController, animated: true)
    }

    func showContactDetail(of contactId: Int) {
        let viewModel = ContactDetailViewModel(contactId: contactId, chatId: nil, context: dcContext)
        let contactDetailController = ContactDetailViewController(viewModel: viewModel)
        let coordinator = ContactDetailCoordinator(dcContext: dcContext, chatId: nil, navigationController: navigationController)
        childCoordinators.append(coordinator)
        contactDetailController.coordinator = coordinator
        navigationController.pushViewController(contactDetailController, animated: true)
    }

    func showDocuments() {
        presentPreview(for: DC_MSG_FILE, messageType2: DC_MSG_AUDIO, messageType3: 0)
    }

    func showGallery() {
        presentPreview(for: DC_MSG_IMAGE, messageType2: DC_MSG_GIF, messageType3: DC_MSG_VIDEO)
    }

    private func presentPreview(for messageType: Int32, messageType2: Int32, messageType3: Int32) {
        let messageIds = dcContext.getChatMedia(chatId: chatId, messageType: messageType, messageType2: messageType2, messageType3: messageType3)
        var mediaUrls: [URL] = []
        for messageId in messageIds {
            let message = DcMsg.init(id: messageId)
            if let url = message.fileURL {
                mediaUrls.insert(url, at: 0)
            }
        }
        previewController = PreviewController(currentIndex: 0, urls: mediaUrls)
        if let previewController = previewController {
            navigationController.pushViewController(previewController.qlController, animated: true)
        }
    }

    func deleteChat() {
        /*
        app will navigate to chatlist or archive and delete the chat there
        notify chatList/archiveList to delete chat AFTER is is visible
        */
        func notifyToDeleteChat() {
            NotificationCenter.default.post(name: dcNotificationChatDeletedInChatDetail, object: nil, userInfo: ["chat_id": self.chatId])
        }

        func showArchive() {
            self.navigationController.popToRootViewController(animated: false) // in main ChatList now
            let controller = ChatListController(dcContext: dcContext, showArchive: true)
            let coordinator = ChatListCoordinator(dcContext: dcContext, navigationController: navigationController)
            childCoordinators.append(coordinator)
            controller.coordinator = coordinator
            navigationController.pushViewController(controller, animated: false)
        }

        CATransaction.begin()
        CATransaction.setCompletionBlock(notifyToDeleteChat)

        let chat = DcChat(id: chatId)
        if chat.isArchived {
            showArchive()
        } else {
            self.navigationController.popToRootViewController(animated: true) // in main ChatList now
        }
        CATransaction.commit()
    }
}

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
        let chat = DcChat(id: chatId)
        switch chat.chatType {
        case .SINGLE:
            if let contactId = chat.contactIds.first {
                let viewModel = ContactDetailViewModel(contactId: contactId, chatId: chatId, context: dcContext)
                let contactDetailController = ContactDetailViewController(viewModel: viewModel)
                let coordinator = ContactDetailCoordinator(dcContext: dcContext, chatId: chatId, navigationController: navigationController)
                childCoordinators.append(coordinator)
                contactDetailController.coordinator = coordinator
                navigationController.pushViewController(contactDetailController, animated: true)
            }
        case .GROUP, .VERIFIEDGROUP:
            let groupChatDetailViewController = GroupChatDetailViewController(chatId: chatId, context: dcContext) // inherits from ChatDetailViewController
            let coordinator = GroupChatDetailCoordinator(dcContext: dcContext, chatId: chatId, navigationController: navigationController)
            childCoordinators.append(coordinator)
            groupChatDetailViewController.coordinator = coordinator
            navigationController.pushViewController(groupChatDetailViewController, animated: true)
        }
    }

    func showContactDetail(of contactId: Int, in chatOfType: ChatType, chatId: Int?) {
        let viewModel = ContactDetailViewModel(contactId: contactId, chatId: chatId, context: dcContext )
        let contactDetailController = ContactDetailViewController(viewModel: viewModel)
        let coordinator = ContactDetailCoordinator(dcContext: dcContext, chatId: chatId, navigationController: navigationController)
        childCoordinators.append(coordinator)
        contactDetailController.coordinator = coordinator
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
        let betterPreviewController = BetterPreviewController(currentIndex: currentIndex, urls: urls)
        let nav = UINavigationController(rootViewController: betterPreviewController)
        let previewController = PreviewController.init(currentIndex: currentIndex, urls: urls)

        navigationController.present(nav, animated: true)
    }
}

class NewGroupAddMembersCoordinator: Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController

    private var childCoordinators: [Coordinator] = []

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.navigationController = navigationController
    }
}

class AddGroupMembersCoordinator: Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController

    private var childCoordinators: [Coordinator] = []

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.navigationController = navigationController
    }

    func showNewContactController() {
        let newContactController = NewContactController()
        newContactController.openChatOnSave = false
        let coordinator = EditContactCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        newContactController.coordinator = coordinator
        navigationController.pushViewController(newContactController, animated: true)
    }
}

class NewGroupCoordinator: Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController
    let mediaPicker: MediaPicker

    private var childCoordinators: [Coordinator] = []

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.navigationController = navigationController
        self.mediaPicker = MediaPicker(navigationController: self.navigationController)
    }

    func showGroupChat(chatId: Int) {
        let chatViewController = ChatViewController(dcContext: dcContext, chatId: chatId)
        let coordinator = ChatViewCoordinator(dcContext: dcContext, navigationController: navigationController, chatId: chatId)
        childCoordinators.append(coordinator)
        chatViewController.coordinator = coordinator
        navigationController.popToRootViewController(animated: false)
        navigationController.pushViewController(chatViewController, animated: true)
    }

    func showPhotoPicker(delegate: MediaPickerDelegate) {
        mediaPicker.showPhotoGallery(delegate: delegate)
    }

    func showCamera(delegate: MediaPickerDelegate) {
        mediaPicker.showCamera(delegate: delegate)
    }

    func showQrCodeInvite(chatId: Int) {
        let qrInviteCodeController = QrInviteViewController(dcContext: dcContext, chatId: chatId)
        qrInviteCodeController.onDismissed = onQRInviteCodeControllerDismissed
        navigationController.pushViewController(qrInviteCodeController, animated: true)
    }

    func showAddMembers(preselectedMembers: Set<Int>, isVerified: Bool) {
        let newGroupController = NewGroupAddMembersViewController(dcContext: dcContext,
                                                                  preselected: preselectedMembers,
                                                                  isVerified: isVerified)
        let coordinator = NewGroupAddMembersCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        newGroupController.coordinator = coordinator
        newGroupController.onMembersSelected = onGroupMembersSelected(_:)
        navigationController.pushViewController(newGroupController, animated: true)
    }

    func onQRInviteCodeControllerDismissed() {
        if let groupNameController = navigationController.topViewController as? NewGroupController {
            groupNameController.updateGroupContactIdsOnQRCodeInvite()
        }
    }

    func onGroupMembersSelected(_ memberIds: Set<Int>) {
        navigationController.popViewController(animated: true)
        if let groupNameController = navigationController.topViewController as? NewGroupController {
            groupNameController.updateGroupContactIdsOnListSelection(memberIds)
        }
    }
}

class ContactDetailCoordinator: Coordinator, ContactDetailCoordinatorProtocol {
    var dcContext: DcContext
    let navigationController: UINavigationController
    var previewController: PreviewController?
    let chatId: Int?

    private var childCoordinators: [Coordinator] = []

    init(dcContext: DcContext, chatId: Int?, navigationController: UINavigationController) {
        self.chatId = chatId
        self.dcContext = dcContext
        self.navigationController = navigationController
    }

    func showChat(chatId: Int) {
        let chatViewController = ChatViewController(dcContext: dcContext, chatId: chatId)
        let coordinator = ChatViewCoordinator(dcContext: dcContext, navigationController: navigationController, chatId: chatId)
        childCoordinators.append(coordinator)
        chatViewController.coordinator = coordinator
        navigationController.popToRootViewController(animated: false)
        navigationController.pushViewController(chatViewController, animated: true)
    }

    func showEditContact(contactId: Int) {
        let editContactController = EditContactController(contactIdForUpdate: contactId)
        let coordinator = EditContactCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        editContactController.coordinator = coordinator
        navigationController.pushViewController(editContactController, animated: true)
    }

    func showDocuments() {
        presentPreview(for: DC_MSG_FILE, messageType2: DC_MSG_AUDIO, messageType3: 0)
    }

    func showGallery() {
        presentPreview(for: DC_MSG_IMAGE, messageType2: DC_MSG_GIF, messageType3: DC_MSG_VIDEO)
    }

    private func presentPreview(for messageType: Int32, messageType2: Int32, messageType3: Int32) {
        guard let chatId = self.chatId else { return }
        let messageIds = dcContext.getChatMedia(chatId: chatId, messageType: messageType, messageType2: messageType2, messageType3: messageType3)
        var mediaUrls: [URL] = []
        for messageId in messageIds {
            let message = DcMsg.init(id: messageId)
            if let url = message.fileURL {
                mediaUrls.insert(url, at: 0)
            }
        }
        previewController = PreviewController(currentIndex: 0, urls: mediaUrls)
        if let previewController = previewController {
            navigationController.pushViewController(previewController.qlController, animated: true)
        }
    }


    func deleteChat() {
        guard let chatId = chatId else {
            return
        }

        /*
        app will navigate to chatlist or archive and delete the chat there
        notify chatList/archiveList to delete chat AFTER is is visible
        */
        func notifyToDeleteChat() {
            NotificationCenter.default.post(name: dcNotificationChatDeletedInChatDetail, object: nil, userInfo: ["chat_id": chatId])
        }

        func showArchive() {
            self.navigationController.popToRootViewController(animated: false) // in main ChatList now
            let controller = ChatListController(dcContext: dcContext, showArchive: true)
            let coordinator = ChatListCoordinator(dcContext: dcContext, navigationController: navigationController)
            childCoordinators.append(coordinator)
            controller.coordinator = coordinator
            navigationController.pushViewController(controller, animated: false)
        }

        CATransaction.begin()
        CATransaction.setCompletionBlock(notifyToDeleteChat)

        let chat = DcChat(id: chatId)
        if chat.isArchived {
            showArchive()
        } else {
            self.navigationController.popToRootViewController(animated: true) // in main ChatList now
        }
        CATransaction.commit()
    }

}

class EditGroupCoordinator: Coordinator {
    let navigationController: UINavigationController
    let dcContext: DcContext
    let mediaPicker: MediaPicker

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.navigationController = navigationController
        mediaPicker = MediaPicker(navigationController: self.navigationController)
    }

    func showPhotoPicker(delegate: MediaPickerDelegate) {
        mediaPicker.showPhotoGallery(delegate: delegate)
    }

    func showCamera(delegate: MediaPickerDelegate) {
        mediaPicker.showCamera(delegate: delegate)
    }

    func navigateBack() {
        navigationController.popViewController(animated: true)
    }
}

class EditContactCoordinator: Coordinator, EditContactCoordinatorProtocol {
    var dcContext: DcContext
    let navigationController: UINavigationController

    var childCoordinators: [Coordinator] = []

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.navigationController = navigationController
    }

    func navigateBack() {
        navigationController.popViewController(animated: true)
    }

    func showChat(chatId: Int) {
        let chatViewController = ChatViewController(dcContext: dcContext, chatId: chatId)
        let coordinator = ChatViewCoordinator(dcContext: dcContext, navigationController: navigationController, chatId: chatId)
        coordinator.chatViewController = chatViewController
        childCoordinators.append(coordinator)
        chatViewController.coordinator = coordinator
        navigationController.popToRootViewController(animated: false)
        navigationController.pushViewController(chatViewController, animated: true)
    }
}


/*
 boilerplate - I tend to remove that interface (cyberta)
 */
protocol ContactDetailCoordinatorProtocol: class {
    func showEditContact(contactId: Int)
    func showChat(chatId: Int)
    func deleteChat()
    func showDocuments()
    func showGallery()
}

protocol EditContactCoordinatorProtocol: class {
    func navigateBack()
    func showChat(chatId: Int)
}

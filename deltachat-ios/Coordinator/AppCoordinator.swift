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

    var rootViewController: UIViewController {
        return tabBarController
    }

    private var childCoordinators: [Coordinator] = []

    private lazy var tabBarController: UITabBarController = {
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [qrController, chatListController, settingsController]
        tabBarController.tabBar.tintColor = DcColors.primary
        return tabBarController
    }()

    // MARK: viewControllers

    private lazy var qrController: UIViewController = {
        let controller = QrViewController(dcContext: dcContext)
        let nav = DcNavigationController(rootViewController: controller)
        let settingsImage = UIImage(named: "report_card")
        nav.tabBarItem = UITabBarItem(title: String.localized("qr_code_title"), image: settingsImage, tag: qrTab)
        let coordinator = QrViewCoordinator(navigationController: nav)
        self.childCoordinators.append(coordinator)
        controller.coordinator = coordinator
        return nav
    }()

    private lazy var chatListController: UIViewController = {
        let controller = ChatListController(dcContext: dcContext, showArchive: false)
        let nav = DcNavigationController(rootViewController: controller)
        let settingsImage = UIImage(named: "chat")
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
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
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

    func presentLoginController() {
        let accountSetupController = AccountSetupController(dcContext: dcContext, editView: false)
        let accountSetupNav = DcNavigationController(rootViewController: accountSetupController)
        let coordinator = AccountSetupCoordinator(dcContext: dcContext, navigationController: accountSetupNav)
        childCoordinators.append(coordinator)
        accountSetupController.coordinator = coordinator
        rootViewController.present(accountSetupNav, animated: false, completion: nil)
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

    override func showCameraViewController() {
        // ignore
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
        let newChatVC = NewChatViewController()
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
}

class AccountSetupCoordinator: Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.navigationController = navigationController
    }

    func showCertCheckOptions() {
        let certificateCheckController = CertificateCheckController(sectionTitle: String.localized("login_certificate_checks"))
        navigationController.pushViewController(certificateCheckController, animated: true)
    }

    func showImapPortOptions() {
        let currentMailPort = DcConfig.mailPort ?? DcConfig.configuredMailPort
        let currentPort = Int(currentMailPort)
        let portSettingsController = PortSettingsController(sectionTitle: String.localized("login_imap_port"),
                                                            ports: [143, 993],
                                                            currentPort: currentPort)
        portSettingsController.onSave = {
            port in
            DcConfig.mailPort = port
        }
        navigationController.pushViewController(portSettingsController, animated: true)
    }

    func showImapSecurityOptions() {
        let securitySettingsController = SecuritySettingsController(title: String.localized("login_imap_security"),
                                                                    type: SecurityType.IMAPSecurity)
        navigationController.pushViewController(securitySettingsController, animated: true)
    }

    func showSmtpPortsOptions() {
        let currentMailPort = DcConfig.sendPort ?? DcConfig.configuredSendPort
        let currentPort = Int(currentMailPort)
        let portSettingsController = PortSettingsController(sectionTitle: String.localized("login_smtp_port"),
                                                            ports: [25, 465, 587],
                                                            currentPort: currentPort)
        portSettingsController.onSave = {
            port in
            DcConfig.sendPort = port
        }
        navigationController.pushViewController(portSettingsController, animated: true)
    }

    func showSmptpSecurityOptions() {
        let securitySettingsController = SecuritySettingsController(title: String.localized("login_imap_security"), type: SecurityType.SMTPSecurity)
        navigationController.pushViewController(securitySettingsController, animated: true)
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

    func showNewGroupController() {
        let newGroupController = NewGroupViewController()
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
        let contactDetailController = ContactDetailViewController(contactId: contactId)
        let coordinator = ContactDetailCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        contactDetailController.coordinator = coordinator
        navigationController.pushViewController(contactDetailController, animated: true)
    }
}

class GroupChatDetailCoordinator: Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController

    private var childCoordinators: [Coordinator] = []

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
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
        let coordinator = EditGroupCoordinator(navigationController: navigationController)
        childCoordinators.append(coordinator)
        editGroupViewController.coordinator = coordinator
        navigationController.pushViewController(editGroupViewController, animated: true)
    }

    func showContactDetail(of contactId: Int) {
        let contactDetailController = ContactDetailViewController(contactId: contactId)
        let coordinator = ContactDetailCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        contactDetailController.coordinator = coordinator
        navigationController.pushViewController(contactDetailController, animated: true)
    }
}

class ChatViewCoordinator: NSObject, Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController
    let chatId: Int
    var chatViewController: ChatViewController!

    var childCoordinators: [Coordinator] = []

    init(dcContext: DcContext, navigationController: UINavigationController, chatId: Int) {
        self.dcContext = dcContext
        self.navigationController = navigationController
        self.chatId = chatId
    }

    func showChatDetail(chatId: Int) {
        let chat = DcChat(id: chatId)
        switch chat.chatType {
        case .SINGLE:
            if let contactId = chat.contactIds.first {
                let contactDetailController = ContactDetailViewController(contactId: contactId)
                contactDetailController.showStartChat = false
                let coordinator = ContactDetailCoordinator(dcContext: dcContext, navigationController: navigationController)
                childCoordinators.append(coordinator)
                contactDetailController.coordinator = coordinator
                navigationController.pushViewController(contactDetailController, animated: true)
            }
        case .GROUP, .VERYFIEDGROUP:
            let groupChatDetailViewController = GroupChatDetailViewController(chatId: chatId) // inherits from ChatDetailViewController
            let coordinator = GroupChatDetailCoordinator(dcContext: dcContext, navigationController: navigationController)
            childCoordinators.append(coordinator)
            groupChatDetailViewController.coordinator = coordinator
            navigationController.pushViewController(groupChatDetailViewController, animated: true)
        }
    }

    func showContactDetail(of contactId: Int, in chatOfType: ChatType) {
        let contactDetailController = ContactDetailViewController(contactId: contactId)
        if chatOfType == .SINGLE {
            contactDetailController.showStartChat = false
        }
        let coordinator = ContactDetailCoordinator(dcContext: dcContext, navigationController: navigationController)
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

    private func sendImage(_ image: UIImage) {
        DispatchQueue.global().async {
            if let compressedImage = image.dcCompress() {
                // at this point image is compressed by 85% by default
                let pixelSize = compressedImage.imageSizeInPixel()
                let width = Int32(exactly: pixelSize.width)!
                let height =  Int32(exactly: pixelSize.height)!
                let path = Utils.saveImage(image: compressedImage)
                let msg = dc_msg_new(mailboxPointer, DC_MSG_IMAGE)
                dc_msg_set_file(msg, path, "image/jpeg")
                dc_msg_set_dimension(msg, width, height)
                dc_send_msg(mailboxPointer, UInt32(self.chatId), msg)
                // cleanup
                dc_msg_unref(msg)
            }
        }
    }

    private func sendVideo(url: NSURL) {
        let msg = dc_msg_new(mailboxPointer, DC_MSG_VIDEO)
        if let path = url.relativePath?.cString(using: .utf8) { //absoluteString?.cString(using: .utf8) {
            dc_msg_set_file(msg, path, "video/mov")
            dc_send_msg(mailboxPointer, UInt32(chatId), msg)
            dc_msg_unref(msg)
        }
    }

    private func handleMediaMessageSuccess() {
        if let chatViewController = self.navigationController.visibleViewController as? MediaSendHandler {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                chatViewController.onSuccess()
            }
        }
    }

    func showCameraViewController() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let cameraViewController = CameraViewController { [weak self] image, _ in
                self?.navigationController.dismiss(animated: true, completion: {
                    self?.handleMediaMessageSuccess()
                })
                if let image = image {
                    self?.sendImage(image)
                }
            }

            navigationController.present(cameraViewController, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: String.localized("chat_camera_unavailable"), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .cancel, handler: { _ in
                self.navigationController.dismiss(animated: true, completion: nil)
            }))
            navigationController.present(alert, animated: true, completion: nil)
        }

    }
    func showVideoLibrary() {
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    [weak self] in
                    switch status {
                    case  .denied, .notDetermined, .restricted:
                        print("denied")
                    case .authorized:
                        self?.presentVideoLibrary()
                    }
                }
            }
        } else {
            presentVideoLibrary()
        }
    }

    private func presentVideoLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let videoPicker = UIImagePickerController()
            videoPicker.title = String.localized("video")
            videoPicker.delegate = self
            videoPicker.sourceType = .photoLibrary
            videoPicker.mediaTypes = [kUTTypeMovie as String, kUTTypeVideo as String]
            navigationController.present(videoPicker, animated: true, completion: nil)
        }
    }
}

extension ChatViewCoordinator: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let videoUrl = info[UIImagePickerController.InfoKey.mediaURL] as? NSURL {
            sendVideo(url: videoUrl)
        }
        navigationController.dismiss(animated: true) {
            self.handleMediaMessageSuccess()
        }
    }
}

class NewGroupCoordinator: Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController

    private var childCoordinators: [Coordinator] = []

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.navigationController = navigationController
    }

    func showGroupNameController(contactIdsForGroup: Set<Int>) {
        let groupNameController = GroupNameController(contactIdsForGroup: contactIdsForGroup)
        let coordinator = GroupNameCoordinator(dcContext: dcContext, navigationController: navigationController)
        childCoordinators.append(coordinator)
        groupNameController.coordinator = coordinator
        navigationController.pushViewController(groupNameController, animated: true)
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

class GroupNameCoordinator: Coordinator {
    var dcContext: DcContext
    let navigationController: UINavigationController

    private var childCoordinators: [Coordinator] = []

    init(dcContext: DcContext, navigationController: UINavigationController) {
        self.dcContext = dcContext
        self.navigationController = navigationController
    }

    func showGroupChat(chatId: Int) {
        let chatViewController = ChatViewController(dcContext: dcContext, chatId: chatId)
        let coordinator = ChatViewCoordinator(dcContext: dcContext, navigationController: navigationController, chatId: chatId)
        childCoordinators.append(coordinator)
        chatViewController.coordinator = coordinator
        navigationController.popToRootViewController(animated: false)
        navigationController.pushViewController(chatViewController, animated: true)
    }
}

class ContactDetailCoordinator: Coordinator, ContactDetailCoordinatorProtocol {
    var dcContext: DcContext
    let navigationController: UINavigationController

    private var childCoordinators: [Coordinator] = []

    init(dcContext: DcContext, navigationController: UINavigationController) {
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
}

class EditGroupCoordinator: Coordinator {
    let navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
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

protocol ContactDetailCoordinatorProtocol: class {
    func showEditContact(contactId: Int)
    func showChat(chatId: Int)
}

protocol EditContactCoordinatorProtocol: class {
    func navigateBack()
    func showChat(chatId: Int)
}

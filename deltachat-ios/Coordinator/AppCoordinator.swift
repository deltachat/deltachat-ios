import UIKit
import Photos
import MobileCoreServices
import DcCore

// MARK: - AppCoordinator
class AppCoordinator: NSObject {

    private let window: UIWindow
    private let dcAccounts: DcAccounts
    // the order below is important as well - and there are two enums, here and at
    // AppStateRestorer (this is error prone and could probably be merged)
    public  let allMediaTab = 0
    private let qrTab = 1
    public  let chatsTab = 2
    private let settingsTab = 3

    private let appStateRestorer = AppStateRestorer.shared

    // MARK: - login view handling
    private lazy var loginNavController: UINavigationController = {
        let nav = UINavigationController() // we change the root, therefore do not set on implicit creation
        return nav
    }()

    // MARK: - tabbar view handling
    lazy var tabBarController: UITabBarController = {
        let qrNavController = createQrNavigationController()
        let allMediaNavController = createAllMediaNavigationController()
        let chatsNavController = createChatsNavigationController()
        let settingsNavController = createSettingsNavigationController()
        let tabBarController = UITabBarController()
        tabBarController.delegate = self
        tabBarController.viewControllers = [allMediaNavController, qrNavController, chatsNavController, settingsNavController]
        tabBarController.tabBar.tintColor = DcColors.primary
        return tabBarController
    }()

    private func createQrNavigationController() -> UINavigationController {
        let root = QrPageController(dcAccounts: dcAccounts)
        let nav = UINavigationController(rootViewController: root)
        let qrCodeTabImage: UIImage?
        qrCodeTabImage = UIImage(systemName: "qrcode")
        nav.tabBarItem = UITabBarItem(title: String.localized("qr_code"), image: qrCodeTabImage, tag: qrTab)
        return nav
    }

    private func createAllMediaNavigationController() -> UINavigationController {
        let root = AllMediaViewController(dcContext: dcAccounts.getSelected())
        let nav = UINavigationController(rootViewController: root)
        let allMediaTabImage = UIImage(systemName: "photo.on.rectangle")
        nav.tabBarItem = UITabBarItem(title: String.localized("menu_all_media"), image: allMediaTabImage, tag: allMediaTab)
        return nav
    }

    private func createChatsNavigationController() -> UINavigationController {
        let root = ChatListViewController(dcContext: dcAccounts.getSelected(), dcAccounts: dcAccounts, isArchive: false)
        let nav = UINavigationController(rootViewController: root)
        let chatTabImage = UIImage(named: "ic_chat")
        nav.tabBarItem = UITabBarItem(title: String.localized("pref_chats"), image: chatTabImage, tag: chatsTab)
        return nav
    }

    private func createSettingsNavigationController() -> UINavigationController {
        let root = SettingsViewController(dcAccounts: dcAccounts)
        let nav = UINavigationController(rootViewController: root)
        let settingsImage: UIImage?
        settingsImage = UIImage(systemName: "gear")
        nav.tabBarItem = UITabBarItem(title: String.localized("menu_settings"), image: settingsImage, tag: settingsTab)
        return nav
    }

    // MARK: - misc
    init(window: UIWindow, dcAccounts: DcAccounts) {
        self.window = window
        self.dcAccounts = dcAccounts
        let dcContext = dcAccounts.getSelected()
        super.init()
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
        if let rootController = self.tabBarController.selectedViewController as? UINavigationController,
           let chatListViewController = rootController.viewControllers.first as? ChatListViewController {
            chatListViewController.setLongTapEditing(false)
            if let msgId, openHighlightedMsg {
                let dcContext = dcAccounts.getSelected()
                let chatViewController = ChatViewController(dcContext: dcContext, chatId: chatId, highlightedMsg: msgId)
                chatListViewController.backButtonUpdateableDataSource = chatViewController
                let webxdcVC = WebxdcViewController(dcContext: dcContext, messageId: msgId)
                let controllers: [UIViewController] = [chatListViewController, chatViewController, webxdcVC]
                rootController.setViewControllers(controllers, animated: animated)
            } else {
                if clearViewControllerStack {
                    rootController.popToRootViewController(animated: false)
                }
                chatListViewController.showChat(chatId: chatId, highlightedMsg: msgId, animated: animated)
            }
        }
    }

    func handleDeepLinkURL(_ url: URL) -> Bool {
        if url.absoluteString.starts(with: "chat.delta.deeplink://webxdc?") {
            return handleWebxdcDeeplink(url: url)
        } else if url.absoluteString.starts(with: "chat.delta.deeplink://chat?") {
            return handleOpenChatDeeplink(url: url)
        } else {
            return false
        }
    }

    private func handleWebxdcDeeplink(url: URL) -> Bool {

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
        } else {
            // check if webxdc is already opened
            if let navController = self.tabBarController.selectedViewController as? UINavigationController,
               let topViewController = navController.topViewController,
               let webxdcController = topViewController as? WebxdcViewController,
               webxdcController.messageId == messageId {
                // do nothing, the app shows the correct view
                return true
            }
        }

        let dcContext = dcAccounts.getSelected()
        let dcMsg = dcContext.getMessage(id: messageId)
        if dcMsg.isValid, dcMsg.type == DC_MSG_WEBXDC {
            showChat(chatId: chatId, msgId: messageId, openHighlightedMsg: true, animated: false, clearViewControllerStack: true)
            return true
        } else {
            showChats()
            return false
        }
    }

    private func handleOpenChatDeeplink(url: URL) -> Bool {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let parameters = url.queryParameters,
              let accountIdString = parameters["accountId"],
              let accountId = Int(accountIdString),
              let chatIdString = parameters["chatId"],
              let chatId = Int(chatIdString) else {
            logger.error("Missing parameters in URL \(url)")
            return false
        }

        if dcAccounts.getSelected().id != accountId {
            if !dcAccounts.select(id: accountId) {
                return false
            }
            appDelegate.reloadDcContext()
        } else {
            // check if chat is already opened
            if let navController = self.tabBarController.selectedViewController as? UINavigationController,
               let topViewController = navController.topViewController,
               let chatViewController = topViewController as? ChatViewController,
               chatViewController.chatId == chatId {
                // do nothing, the app shows the correct view
                return true
            }
        }

        let chat = dcAccounts.getSelected().getChat(chatId: chatId)
        if chat.isValid {
            showChat(chatId: chatId, animated: false, clearViewControllerStack: true)
        } else {
            showChats()
        }
        return true
    }

    func handleMailtoURL(_ url: URL) -> Bool {
        if RelayHelper.shared.parseMailtoUrl(url) {
            showTab(index: chatsTab)
            if let rootController = self.tabBarController.selectedViewController as? UINavigationController {
                rootController.popToRootViewController(animated: false)
                if let controller = rootController.viewControllers.first as? ChatListViewController {
                    controller.handleMailto(askToChat: RelayHelper.shared.askToChatWithMailto)
                    return true
                }
            }
        } else {
            logger.warning("Could not parse mailto: URL")
        }
        RelayHelper.shared.finishRelaying()
        return false
    }

    func handleDeltaChatInvitation(url: URL, from viewController: UIViewController) {
        coordinate(qrCode: url.absoluteString, from: viewController)
    }

    func handleProxySelection(on viewController: UIViewController, dcContext: DcContext, proxyURL: String) {
        let host = dcContext.checkQR(qrCode: proxyURL).text1 ?? ""

        let selectAlert = UIAlertController(
            title: String.localized("proxy_use_proxy"),
            message: String.localized(stringID: "proxy_use_proxy_confirm", parameter: host),
            preferredStyle: .alert
        )

        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .cancel)
        let selectAction = UIAlertAction(title: String.localized("proxy_use_proxy"), style: .default) { [weak self] _ in

            guard let self else { return }
            if dcContext.setConfigFromQR(qrCode: proxyURL) {
                dcAccounts.restartIO()
            }
        }

        selectAlert.addAction(cancelAction)
        selectAlert.addAction(selectAction)
        if proxyURL.starts(with: "http") {
            selectAlert.addAction(UIAlertAction(title: String.localized("open"), style: .default) { _ in
                if let url = URL(string: proxyURL) {
                    UIApplication.shared.open(url)
                }
            })
        }

        viewController.present(selectAlert, animated: true)
    }

    func handleQRCode(_ code: String) {
        if code.lowercased().starts(with: "dcaccount:")
           || code.lowercased().starts(with: "dclogin:") {
            if dcAccounts.getSelected().isConfigured() {
                // if account is configured it means we didn't come from Welcome screen nor from QR scanner,
                // instead, user clicked a dcaccount:// URI directly, so we need to switch to a new account:
                guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
                _ = dcAccounts.add()
                appDelegate.reloadDcContext(accountCode: code)
            } else {
                presentWelcomeController(accountCode: code)
            }
        } else {
            showTab(index: qrTab)
            if let navController = self.tabBarController.selectedViewController as? UINavigationController,
               let topViewController = navController.topViewController,
               let qrPageController = topViewController as? QrPageController {
                coordinate(qrCode: code, from: qrPageController)
            }
        }
    }

    /// Works for both i.delta.chat and QR-codes
    func coordinate(qrCode code: String, from viewController: UIViewController) {
        let dcContext = dcAccounts.getSelected()

        showChats()
        let qrParsed: DcLot = dcContext.checkQR(qrCode: code)
        let state = Int32(qrParsed.state)
        switch state {
        case DC_QR_ASK_VERIFYCONTACT:
            let nameAndAddress = dcContext.getContact(id: qrParsed.id).nameNAddr
            joinSecureJoin(
                alertMessage: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), nameAndAddress),
                code: code,
                viewController: viewController,
                dcContext: dcContext
            )

        case DC_QR_ASK_VERIFYGROUP:
            let groupName = qrParsed.text1 ?? "ErrGroupName"
            joinSecureJoin(
                alertMessage: String.localizedStringWithFormat(String.localized("qrscan_ask_join_group"), groupName),
                code: code,
                viewController: viewController,
                dcContext: dcContext
            )

        case DC_QR_FPR_WITHOUT_ADDR:
            let msg = String.localized("qrscan_no_addr_found") + "\n\n" +
                String.localized("qrscan_fingerprint_label") + ":\n" + (qrParsed.text1 ?? "")
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            viewController.present(alert, animated: true, completion: nil)

        case DC_QR_FPR_MISMATCH:
            let nameAndAddress = dcContext.getContact(id: qrParsed.id).nameNAddr
            let msg = String.localizedStringWithFormat(String.localized("qrscan_fingerprint_mismatch"), nameAndAddress)
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            viewController.present(alert, animated: true, completion: nil)

        case DC_QR_ADDR, DC_QR_FPR_OK:
            let nameAndAddress = dcContext.getContact(id: qrParsed.id).nameNAddr
            let msg = String.localizedStringWithFormat(String.localized(state==DC_QR_ADDR ? "ask_start_chat_with" : "qrshow_x_verified"), nameAndAddress)
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default, handler: nil))
            alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { [weak self] _ in
                let chatId = dcContext.createChatByContactId(contactId: qrParsed.id)
                self?.showChat(chatId: chatId)
            }))
            viewController.present(alert, animated: true, completion: nil)

        case DC_QR_TEXT:
            let msg = String.localizedStringWithFormat(String.localized("qrscan_contains_text"), qrParsed.text1 ?? "")
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            viewController.present(alert, animated: true, completion: nil)

        case DC_QR_URL:
            let url = qrParsed.text1 ?? ""
            let msg = String.localizedStringWithFormat(String.localized("qrscan_contains_url"), url)
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default, handler: nil))
            alert.addAction(UIAlertAction(title: String.localized("open"), style: .default, handler: { _ in
                if let url = URL(string: url) {
                    UIApplication.shared.open(url)
                }
            }))
            viewController.present(alert, animated: true, completion: nil)

        case DC_QR_ACCOUNT, DC_QR_LOGIN:
            let msg = String.localizedStringWithFormat(String.localized(state == DC_QR_ACCOUNT ? "qraccount_ask_create_and_login_another" : "qrlogin_ask_login_another"), qrParsed.text1 ?? "")
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
                guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
                _ = self.dcAccounts.add()
                appDelegate.reloadDcContext(accountCode: code)
            }))
            viewController.present(alert, animated: true, completion: nil)

        case DC_QR_BACKUP, DC_QR_BACKUP2:
            // alert is shown in WelcomeViewController
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            _ = dcAccounts.add()
            appDelegate.reloadDcContext(accountCode: code)

        case DC_QR_WEBRTC_INSTANCE:
            guard let domain = qrParsed.text1 else { return }
            let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("videochat_instance_from_qr"), domain),
                                          message: nil,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default))
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
                let success = dcContext.setConfigFromQR(qrCode: code)
                if !success {
                    logger.warning("Could not set webrtc instance from QR code.")
                    // TODO: alert?!
                }
            }))
            viewController.present(alert, animated: true)

        case DC_QR_WITHDRAW_VERIFYCONTACT:
            let alert = UIAlertController(title: String.localized("withdraw_verifycontact_explain"),
                                          message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default))
            alert.addAction(UIAlertAction(title: String.localized("withdraw_qr_code"), style: .destructive, handler: { _ in
                _ = dcContext.setConfigFromQR(qrCode: code)
            }))
            viewController.present(alert, animated: true)

        case DC_QR_REVIVE_VERIFYCONTACT:
            let alert = UIAlertController(title: String.localized("revive_verifycontact_explain"),
                                          message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default))
            alert.addAction(UIAlertAction(title: String.localized("revive_qr_code"), style: .default, handler: { _ in
                _ = dcContext.setConfigFromQR(qrCode: code)
            }))
            viewController.present(alert, animated: true)

        case DC_QR_WITHDRAW_VERIFYGROUP:
            guard let groupName = qrParsed.text1 else { return }
            let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("withdraw_verifygroup_explain"), groupName),
                                          message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default))
            alert.addAction(UIAlertAction(title: String.localized("withdraw_qr_code"), style: .destructive, handler: { _ in
                _ = dcContext.setConfigFromQR(qrCode: code)
            }))
            viewController.present(alert, animated: true)

        case DC_QR_REVIVE_VERIFYGROUP:
            guard let groupName = qrParsed.text1 else { return }
            let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("revive_verifygroup_explain"), groupName),
                                          message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default))
            alert.addAction(UIAlertAction(title: String.localized("revive_qr_code"), style: .default, handler: { _ in
                _ = dcContext.setConfigFromQR(qrCode: code)
            }))
            viewController.present(alert, animated: true)
        case DC_QR_PROXY:
            handleProxySelection(on: viewController, dcContext: dcContext, proxyURL: code)
        default:
            var msg = String.localizedStringWithFormat(String.localized("qrscan_contains_text"), code)
            if state == DC_QR_ERROR {
                if let errorMsg = qrParsed.text1 {
                    msg = errorMsg + "\n\n" + msg
                }
            }
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            viewController.present(alert, animated: true, completion: nil)
        }
    }

    private func joinSecureJoin(alertMessage: String, code: String, viewController: UIViewController, dcContext: DcContext) {
        let alert = UIAlertController(title: alertMessage,
                                      message: nil,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { [weak self] _ in
            let chatId = dcContext.joinSecurejoin(qrCode: code)
            if chatId != 0 {
                self?.showChat(chatId: chatId)
            } else {
                self?.showErrorAlert(error: dcContext.lastErrorString, viewController: viewController)
            }
        }))
        viewController.present(alert, animated: true, completion: nil)
    }

    private func showErrorAlert(error: String, viewController: UIViewController) {
        let alert = UIAlertController(title: String.localized("error"), message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
            alert.dismiss(animated: true)
        }))
        viewController.present(alert, animated: true)
    }

    // MARK: - coordinator
    private func showChats() {
        showTab(index: chatsTab)
    }

    private func showChat(chatId: Int) {
        showChat(chatId: chatId, animated: false, clearViewControllerStack: true)
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

        let viewControllers: [UIViewController]

        if let accountCode {
            let qr = dcAccounts.getSelected().checkQR(qrCode: accountCode)
            if qr.state == DC_QR_BACKUP || qr.state == DC_QR_BACKUP2 {
                viewControllers = [WelcomeViewController(dcAccounts: dcAccounts, accountCode: accountCode)]
            } else {
                viewControllers = [
                    WelcomeViewController(dcAccounts: dcAccounts),
                    InstantOnboardingViewController(dcAccounts: dcAccounts, qrCodeData: accountCode)
                ]
            }
        } else {
            viewControllers = [WelcomeViewController(dcAccounts: dcAccounts)]
        }

        loginNavController.setViewControllers(viewControllers, animated: false)
        window.rootViewController = loginNavController
        window.makeKeyAndVisible()

        // the applicationIconBadgeNumber is remembered by the system even on reinstalls (just tested on ios 13.3.1),
        // to avoid appearing an old number of a previous installation, we reset the counter manually.
        // but even when this changes in ios, we need the reset as we allow account-deletion also in-app.
        NotificationManager.updateBadgeCounters(forceZero: true)
    }

    func presentTabBarController() {
        window.rootViewController = tabBarController
        showTab(index: chatsTab)
        window.makeKeyAndVisible()
    }

    func presentQrCodeController() {
        popTabsToRootViewControllers()
        window.rootViewController = tabBarController
        showTab(index: qrTab)
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
        // call `willMove()` for the root view controllers of each tab, after popping to root.
        // this is not always done by `setViewControllers()` the documentation is vague on this point:
        // <https://developer.apple.com/documentation/uikit/uitabbarcontroller/1621177-setviewcontrollers>
        // (calling `willMove()` is needed eg. to remove observers - otherwise we have a memory leak)
        self.tabBarController.viewControllers?.forEach { controller in
            if let navController = controller as? UINavigationController {
                navController.popToRootViewController(animated: false)
                navController.viewControllers[0].willMove(toParent: nil)
            }
        }

        self.tabBarController.setViewControllers([createAllMediaNavigationController(),
                                                  createQrNavigationController(),
                                                  createChatsNavigationController(),
                                                  createSettingsNavigationController()], animated: false)
        presentTabBarController()
        NotificationManager.updateBadgeCounters()
    }
}

extension AppCoordinator: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // if the chatlist is already visible when tapping, scroll chatlist to top
        if let navigationController = viewController as? UINavigationController,
           let chatListViewController = navigationController.viewControllers.first as? ChatListViewController,
           let viewModel = chatListViewController.viewModel,
           let chatsTab = tabBarController.selectedViewController as? UINavigationController,
           chatsTab.topViewController == chatListViewController {
            if viewModel.searchActive {
                chatListViewController.quitSearch(animated: true) // this includes scrollToTop()
            } else {
                chatListViewController.tableView.scrollToTop(animated: true)
            }
        }

        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        appStateRestorer.tabBarController(tabBarController, didSelect: viewController)
    }
}

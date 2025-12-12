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
        tabBarController.delegate = self
        tabBarController.viewControllers = [qrNavController, chatsNavController, settingsNavController]
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
        } else if url.absoluteString.starts(with: "chat.delta.deeplink://share?") {
            return handleShareDeeplink(url: url)
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
    
    private func handleShareDeeplink(url: URL) -> Bool {
        guard let parameters = url.queryParameters,
              let data = parameters["data"]?.data(using: .utf8),
              let providers = try? JSONDecoder().decode([CodableNSItemProvider].self, from: data)
        else {
            logger.error("Missing data parameter or incorrect format in URL \(url)")
            return false
        }
        
        // Switch account if needed
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
           let accountId = parameters["accountId"].flatMap(Int.init) {
            if dcAccounts.getSelected().id != accountId {
                if !dcAccounts.select(id: accountId) { return false }
                appDelegate.reloadDcContext()
            }
        }
        
        // Create messages
        let dcContext = dcAccounts.getSelected()
        let messages = providers.map {
            switch $0 {
            case let .contentsAt(url, viewType):
                let msg = dcContext.newMessage(viewType: viewType)
                msg.setFile(filepath: url.relativePath)
                return msg
            case .text(let text):
                let msg = dcContext.newMessage(viewType: DC_MSG_TEXT)
                msg.text = text
                return msg
            }
        }
        
        // Ask for sending messages
        if let chatId = parameters["chatId"].flatMap(Int.init) {
            showChat(chatId: chatId)
        } else {
            showChats()
            let nvc = tabBarController.selectedViewController as? UINavigationController
            nvc?.popToRootViewController(animated: false)
        }
        RelayHelper.shared.setShareMessages(messages: messages)

        return true
    }

    func handleMailtoURL(_ url: URL, askToChat: Bool = true) -> Bool {
        if RelayHelper.shared.parseMailtoUrl(url) {
            showTab(index: chatsTab)
            if let rootController = self.tabBarController.selectedViewController as? UINavigationController {
                rootController.popToRootViewController(animated: false)
                if let controller = rootController.viewControllers.first as? ChatListViewController {
                    controller.handleMailto(askToChat: askToChat)
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
            let name = dcContext.getContact(id: qrParsed.id).displayName
            joinSecureJoin(
                alertMessage: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), name),
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

        case DC_QR_ASK_VERIFYBROADCAST:
            let broadcastName = qrParsed.text1 ?? "ErrBroadcastName"
            joinSecureJoin(
                alertMessage: String.localizedStringWithFormat(String.localized("qrscan_ask_join_channel"), broadcastName),
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
            let name = dcContext.getContact(id: qrParsed.id).displayName
            let msg = String.localizedStringWithFormat(String.localized("qrscan_fingerprint_mismatch"), name)
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            viewController.present(alert, animated: true, completion: nil)

        case DC_QR_ADDR, DC_QR_FPR_OK:
            let name = dcContext.getContact(id: qrParsed.id).displayName
            let msg = String.localizedStringWithFormat(String.localized(state==DC_QR_ADDR ? "ask_start_chat_with" : "qrshow_x_verified"), name)
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
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: String.localized("global_menu_edit_copy_desktop"), style: .default, handler: { _ in
                UIPasteboard.general.string = qrParsed.text1
            }))
            viewController.present(alert, animated: true, completion: nil)

        case DC_QR_URL:
            let url = qrParsed.text1 ?? ""
            let msg = String.localizedStringWithFormat(String.localized("qrscan_contains_url"), url)
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: String.localized("open"), style: .default, handler: { _ in
                if let url = URL(string: url) {
                    UIApplication.shared.open(url)
                }
            }))
            viewController.present(alert, animated: true, completion: nil)

        case DC_QR_ACCOUNT, DC_QR_LOGIN:
            let alert = UIAlertController(title: String.localized("confirm_add_transport"), message: qrParsed.text1, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { [weak self] _ in
                Utils.authenticateDeviceOwner(reason: String.localized("edit_transport")) { [weak self] in
                    guard let self = self else { return }
                    popTabsToRootViewControllers()
                    showTab(index: settingsTab)
                    guard let root = tabBarController.selectedViewController as? UINavigationController else { return }
                    let advancedViewController = AdvancedViewController(dcAccounts: dcAccounts)
                    let transportViewController = TransportListViewController(dcContext: dcContext, dcAccounts: dcAccounts, continueQrScan: code)
                    root.setViewControllers([root.viewControllers[0], advancedViewController, transportViewController], animated: true)
                }
            }))
            viewController.present(alert, animated: true, completion: nil)

        case DC_QR_BACKUP2:
            // alert is shown in WelcomeViewController
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            _ = dcAccounts.add()
            appDelegate.reloadDcContext(accountCode: code)

        case DC_QR_BACKUP_TOO_NEW:
            let alert = UIAlertController(title: String.localized("multidevice_receiver_needs_update"), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            viewController.present(alert, animated: true)

        case DC_QR_WITHDRAW_VERIFYCONTACT:
            let alert = UIAlertController(title: String.localized("withdraw_verifycontact_explain"),
                                          message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default))
            alert.addAction(UIAlertAction(title: String.localized("withdraw_qr_code"), style: .destructive, handler: { _ in
                _ = dcContext.setConfigFromQR(qrCode: code)
            }))
            viewController.present(alert, animated: true)

        case DC_QR_REVIVE_VERIFYCONTACT, DC_QR_REVIVE_VERIFYGROUP, DC_QR_REVIVE_JOINBROADCAST:
            let alert = UIAlertController(title: String.localized("revive_verifycontact_explain"),
                                          message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default))
            alert.addAction(UIAlertAction(title: String.localized("revive_qr_code"), style: .default, handler: { _ in
                _ = dcContext.setConfigFromQR(qrCode: code)
            }))
            viewController.present(alert, animated: true)

        case DC_QR_WITHDRAW_VERIFYGROUP, DC_QR_WITHDRAW_JOINBROADCAST:
            guard let name = qrParsed.text1 else { return }
            let msg = String.localizedStringWithFormat(String.localized(state == DC_QR_WITHDRAW_JOINBROADCAST ? "withdraw_joinbroadcast_explain" : "withdraw_verifygroup_explain"), name)
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default))
            alert.addAction(UIAlertAction(title: String.localized("withdraw_qr_code"), style: .destructive, handler: { _ in
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
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: String.localized("global_menu_edit_copy_desktop"), style: .default, handler: { _ in
                UIPasteboard.general.string = msg
            }))
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
                viewController.logAndAlert(error: dcContext.lastErrorString)
            }
        }))
        viewController.present(alert, animated: true, completion: nil)
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
            if qr.state == DC_QR_BACKUP2 || qr.state == DC_QR_BACKUP_TOO_NEW {
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

        self.tabBarController.setViewControllers([createQrNavigationController(),
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

import UIKit
import DcCore

class QrPageController: UIPageViewController {
    private let dcContext: DcContext
    private let dcAccounts: DcAccounts
    var progressObserver: NSObjectProtocol?
    let qrCodeReaderController: QrCodeReaderController
    let qrViewController: QrViewController

    private var selectedIndex: Int = 0

    private var qrCodeHint: String {
        var qrCodeHint = ""
        if dcContext.isConfigured() {
            // we cannot use dc_contact_get_displayname() as this would result in "Me" instead of the real name
            let name = dcContext.getConfig("displayname") ?? ""
            let addr = dcContext.getConfig("addr") ?? ""
            var nameAndAddress = ""
            if name.isEmpty {
                nameAndAddress = addr
            } else {
                nameAndAddress = "\(name) (\(addr))"
            }
            qrCodeHint = String.localizedStringWithFormat(
                String.localized("qrshow_join_contact_hint"),
                nameAndAddress
            )
        }
        return qrCodeHint
    }

    private lazy var qrSegmentControl: UISegmentedControl = {
        let control = UISegmentedControl(
            items: [String.localized("qrshow_title"), String.localized("qrscan_title")]
        )
        control.tintColor = DcColors.primary
        control.addTarget(self, action: #selector(qrSegmentControlChanged), for: .valueChanged)
        control.selectedSegmentIndex = 0
        return control
    }()

    private lazy var moreButton: UIBarButtonItem = {
        let image: UIImage?
        if #available(iOS 13.0, *) {
            image = UIImage(systemName: "ellipsis.circle")
        } else {
            image = UIImage(named: "ic_more")
        }
        return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(showMoreOptions))
    }()

    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()

        qrViewController = QrViewController(dcContext: dcContext)
        qrCodeReaderController = QrCodeReaderController(title: String.localized("qrscan_title"))
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: [:])

        qrCodeReaderController.delegate = self
        qrViewController.qrCodeHint = self.qrCodeHint
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        delegate = self
        navigationItem.titleView = qrSegmentControl
        navigationItem.rightBarButtonItem = moreButton

        setViewControllers(
            [qrViewController],
            direction: .forward,
            animated: true,
            completion: nil
        )

        if #available(iOS 13, *) {
            self.navigationController?.navigationBar.scrollEdgeAppearance = self.navigationController?.navigationBar.standardAppearance
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        // QrCodeReaderController.viewWillAppear() is on called on section change, not on main-tab change
        qrCodeReaderController.startSession()
        updateHintTextIfNeeded()    // needed in case user changes profile name
    }

    override func viewWillDisappear(_ animated: Bool) {
        // QrCodeReaderController.viewWillDisappear() is on called on section change, not on main-tab change
        qrCodeReaderController.stopSession()
        self.progressObserver = nil
    }

    // MARK: - actions
    @objc private func qrSegmentControlChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            setViewControllers([qrViewController], direction: .reverse, animated: true, completion: nil)
        } else {
            setViewControllers([qrCodeReaderController], direction: .forward, animated: true, completion: nil)
        }
    }

    @objc private func showMoreOptions() {
        let alert = UIAlertController(title: String.localized("qr_code"), message: nil, preferredStyle: .safeActionSheet)
        if qrSegmentControl.selectedSegmentIndex == 0 {
            alert.addAction(UIAlertAction(title: String.localized("menu_share"), style: .default, handler: share(_:)))
            alert.addAction(UIAlertAction(title: String.localized("menu_copy_to_clipboard"), style: .default, handler: copyToClipboard(_:)))
            alert.addAction(UIAlertAction(title: String.localized("withdraw_qr_code"), style: .default, handler: withdrawQrCode(_:)))
        }
        alert.addAction(UIAlertAction(title: String.localized("paste_from_clipboard"), style: .default, handler: pasteFromClipboard(_:)))

        if dcContext.isChatmail == false {
            let addContactManuallyAction = UIAlertAction(title: String.localized("menu_new_classic_contact"), style: .default, handler: { [weak self] _ in
                guard let self else { return }

                let newContactController = NewContactController(dcContext: self.dcContext)
                self.navigationController?.pushViewController(newContactController, animated: true)
            })

            alert.addAction(addContactManuallyAction)
        }

        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        self.present(alert, animated: true, completion: nil)
    }

    @objc func share(_ action: UIAlertAction) {
        if let inviteLink = Utils.getInviteLink(context: dcContext, chatId: 0) {
            Utils.share(url: inviteLink, parentViewController: self, sourceItem: moreButton)
        }
    }

    @objc func copyToClipboard(_ action: UIAlertAction) {
        UIPasteboard.general.string = Utils.getInviteLink(context: dcContext, chatId: 0)
    }

    @objc func withdrawQrCode(_ action: UIAlertAction) {
        let alert = UIAlertController(title: String.localized("withdraw_verifycontact_explain"), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default))
        alert.addAction(UIAlertAction(title: String.localized("withdraw_qr_code"), style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            guard let code = dcContext.getSecurejoinQr(chatId: 0) else { return }
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            _ = self.dcContext.setConfigFromQR(qrCode: code)
            setViewControllers([QrViewController(dcContext: dcContext, qrCodeHint: qrCodeHint)], direction: .reverse, animated: false, completion: nil)
            appDelegate.appCoordinator.presentTabBarController()
        }))
        present(alert, animated: true)
    }

    @objc func pasteFromClipboard(_ action: UIAlertAction) {
        handleQrCode(UIPasteboard.general.string ?? "")
    }

    // MARK: - update
    private func updateHintTextIfNeeded() {
        let newHint = qrCodeHint
        if newHint != qrViewController.qrCodeHint {
            qrViewController.qrCodeHint = newHint
        }
    }

    // MARK: - coordinator
    private func showChats() {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.appCoordinator.showTab(index: appDelegate.appCoordinator.chatsTab)
        }
    }

    private func showChat(chatId: Int) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.appCoordinator.showChat(chatId: chatId, animated: false, clearViewControllerStack: true)
        }
    }
}

// MARK: - UIPageViewControllerDataSource, UIPageViewControllerDelegate
extension QrPageController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if viewController is QrViewController {
            return nil
        } else {
            return qrViewController
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if viewController is QrViewController {
            return qrCodeReaderController
        } else {
            return nil
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        if pendingViewControllers.first is QrViewController {
            qrSegmentControl.selectedSegmentIndex = 0
        } else {
            qrSegmentControl.selectedSegmentIndex = 1
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if !completed {
            if previousViewControllers.first is QrViewController {
                qrSegmentControl.selectedSegmentIndex = 0
            } else {
                qrSegmentControl.selectedSegmentIndex = 1
            }
        }
    }
}

// MARK: - QRCodeDelegate
extension QrPageController: QrCodeReaderDelegate {

    func handleQrCode(_ code: String) {
        self.showChats()
        let qrParsed: DcLot = self.dcContext.checkQR(qrCode: code)
        let state = Int32(qrParsed.state)
        switch state {
        case DC_QR_ASK_VERIFYCONTACT:
            let nameAndAddress = dcContext.getContact(id: qrParsed.id).nameNAddr
            joinSecureJoin(alertMessage: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), nameAndAddress), code: code)

        case DC_QR_ASK_VERIFYGROUP:
            let groupName = qrParsed.text1 ?? "ErrGroupName"
            joinSecureJoin(alertMessage: String.localizedStringWithFormat(String.localized("qrscan_ask_join_group"), groupName), code: code)

        case DC_QR_FPR_WITHOUT_ADDR:
            let msg = String.localized("qrscan_no_addr_found") + "\n\n" +
                String.localized("qrscan_fingerprint_label") + ":\n" + (qrParsed.text1 ?? "")
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)

        case DC_QR_FPR_MISMATCH:
            let nameAndAddress = dcContext.getContact(id: qrParsed.id).nameNAddr
            let msg = String.localizedStringWithFormat(String.localized("qrscan_fingerprint_mismatch"), nameAndAddress)
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)

        case DC_QR_ADDR, DC_QR_FPR_OK:
            let nameAndAddress = dcContext.getContact(id: qrParsed.id).nameNAddr
            let msg = String.localizedStringWithFormat(String.localized(state==DC_QR_ADDR ? "ask_start_chat_with" : "qrshow_x_verified"), nameAndAddress)
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default, handler: nil))
            alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { _ in
                let chatId = self.dcContext.createChatByContactId(contactId: qrParsed.id)
                self.showChat(chatId: chatId)
            }))
            present(alert, animated: true, completion: nil)

        case DC_QR_TEXT:
            let msg = String.localizedStringWithFormat(String.localized("qrscan_contains_text"), qrParsed.text1 ?? "")
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)

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
            present(alert, animated: true, completion: nil)

        case DC_QR_ACCOUNT, DC_QR_LOGIN:
            let msg = String.localizedStringWithFormat(String.localized(state == DC_QR_ACCOUNT ? "qraccount_ask_create_and_login_another" : "qrlogin_ask_login_another"), qrParsed.text1 ?? "")
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
                guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
                _ = self.dcAccounts.add()
                appDelegate.reloadDcContext(accountCode: code)
            }))
            present(alert, animated: true, completion: nil)

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
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { [weak self] _ in
                guard let self else { return }
                let success = self.dcContext.setConfigFromQR(qrCode: code)
                if !success {
                    logger.warning("Could not set webrtc instance from QR code.")
                    // TODO: alert?!
                }
            }))
            present(alert, animated: true)

        case DC_QR_WITHDRAW_VERIFYCONTACT:
            let alert = UIAlertController(title: String.localized("withdraw_verifycontact_explain"),
                                          message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default))
            alert.addAction(UIAlertAction(title: String.localized("withdraw_qr_code"), style: .destructive, handler: { [weak self] _ in
                _ = self?.dcContext.setConfigFromQR(qrCode: code)
            }))
            present(alert, animated: true)

        case DC_QR_REVIVE_VERIFYCONTACT:
            let alert = UIAlertController(title: String.localized("revive_verifycontact_explain"),
                                          message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default))
            alert.addAction(UIAlertAction(title: String.localized("revive_qr_code"), style: .default, handler: { [weak self] _ in
                _ = self?.dcContext.setConfigFromQR(qrCode: code)
            }))
            present(alert, animated: true)

        case DC_QR_WITHDRAW_VERIFYGROUP:
            guard let groupName = qrParsed.text1 else { return }
            let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("withdraw_verifygroup_explain"), groupName),
                                          message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default))
            alert.addAction(UIAlertAction(title: String.localized("withdraw_qr_code"), style: .destructive, handler: { [weak self] _ in
                _ = self?.dcContext.setConfigFromQR(qrCode: code)
            }))
            present(alert, animated: true)

        case DC_QR_REVIVE_VERIFYGROUP:
            guard let groupName = qrParsed.text1 else { return }
            let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("revive_verifygroup_explain"), groupName),
                                          message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default))
            alert.addAction(UIAlertAction(title: String.localized("revive_qr_code"), style: .default, handler: { [weak self] _ in
                _ = self?.dcContext.setConfigFromQR(qrCode: code)
            }))
            present(alert, animated: true)

        default:
            var msg = String.localizedStringWithFormat(String.localized("qrscan_contains_text"), code)
            if state == DC_QR_ERROR {
                if let errorMsg = qrParsed.text1 {
                    msg = errorMsg + "\n\n" + msg
                }
            }
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }

    private func joinSecureJoin(alertMessage: String, code: String) {
        let alert = UIAlertController(title: alertMessage,
                                      message: nil,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
            let chatId = self.dcContext.joinSecurejoin(qrCode: code)
            if chatId != 0 {
                self.showChat(chatId: chatId)
            } else {
                self.showErrorAlert(error: self.dcContext.lastErrorString)
            }
        }))
        present(alert, animated: true, completion: nil)
    }

    private func showErrorAlert(error: String) {
        let alert = UIAlertController(title: String.localized("error"), message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
            alert.dismiss(animated: true, completion: nil)
        }))
    }
}

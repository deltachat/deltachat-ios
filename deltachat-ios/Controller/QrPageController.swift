import UIKit
import DcCore

class QrPageController: UIPageViewController, ProgressAlertHandler {
    private let dcContext: DcContext
    weak var progressAlert: UIAlertController?
    var progressObserver: NSObjectProtocol?
    var qrCodeReaderController: QrCodeReaderController?

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

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: [:])
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

        let qrController = QrViewController(dcContext: dcContext, qrCodeHint: qrCodeHint)
        setViewControllers(
            [qrController],
            direction: .forward,
            animated: true,
            completion: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        // QrCodeReaderController::viewWillAppear() is on called on section change, not on main-tab change
        if let qrCodeReaderController = self.qrCodeReaderController {
            qrCodeReaderController.startSession()
        }
        updateHintTextIfNeeded()    // needed in case user changes profile name
    }

    override func viewWillDisappear(_ animated: Bool) {
        // QrCodeReaderController::viewWillDisappear() is on called on section change, not on main-tab change
        if let qrCodeReaderController = self.qrCodeReaderController {
            qrCodeReaderController.stopSession()
        }

        self.progressObserver = nil
    }

    // MARK: - actions
    @objc private func qrSegmentControlChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            let qrController = QrViewController(dcContext: dcContext, qrCodeHint: qrCodeHint)
            setViewControllers([qrController], direction: .reverse, animated: true, completion: nil)
        } else {
            let qrCodeReaderController = makeQRReader()
            self.qrCodeReaderController = qrCodeReaderController
            setViewControllers([qrCodeReaderController], direction: .forward, animated: true, completion: nil)
        }
    }

    // MARK: - factory
    private func makeQRReader() -> QrCodeReaderController {
        let qrReader = QrCodeReaderController()
        qrReader.delegate = self
        return qrReader
    }

    // MARK: - update
    private func updateHintTextIfNeeded() {
        for case let qrViewController as QrViewController in self.viewControllers ?? [] {
            let newHint = qrCodeHint
            if qrCodeHint != qrViewController.qrCodeHint {
                qrViewController.qrCodeHint = newHint
            }
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
            appDelegate.appCoordinator.showChat(chatId: chatId, clearViewControllerStack: true)
        }
    }
}

// MARK: - UIPageViewControllerDataSource, UIPageViewControllerDelegate
extension QrPageController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if viewController is QrViewController {
            return nil
        }
        return QrViewController(dcContext: dcContext, qrCodeHint: qrCodeHint)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if viewController is QrViewController {
            return makeQRReader()
        }
        return nil
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            if previousViewControllers.first is QrViewController {
                qrSegmentControl.selectedSegmentIndex = 1
            } else {
                qrSegmentControl.selectedSegmentIndex = 0
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
            let nameAndAddress = DcContact(id: qrParsed.id).nameNAddr
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
            let nameAndAddress = DcContact(id: qrParsed.id).nameNAddr
            let msg = String.localizedStringWithFormat(String.localized("qrscan_fingerprint_mismatch"), nameAndAddress)
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)

        case DC_QR_ADDR, DC_QR_FPR_OK:
            let nameAndAddress = DcContact(id: qrParsed.id).nameNAddr
            let msg = String.localizedStringWithFormat(String.localized(state==DC_QR_ADDR ? "ask_start_chat_with" : "qrshow_x_verified"), nameAndAddress)
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { _ in
                let chatId = self.dcContext.createChatByContactId(contactId: qrParsed.id)
                self.showChat(chatId: chatId)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default, handler: nil))
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
            alert.addAction(UIAlertAction(title: String.localized("open"), style: .default, handler: { _ in
                if let url = URL(string: url) {
                    UIApplication.shared.open(url)
                }
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)

        case DC_QR_ACCOUNT:
            let alert = UIAlertController(title: String.localized("qraccount_use_on_new_install"), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default))
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
            alert.dismiss(animated: true, completion: nil)
            self.showProgressAlert(title: String.localized("one_moment")+"\n\n", dcContext: self.dcContext)
            // execute blocking secure join in background
            DispatchQueue.global(qos: .background).async {
                self.addSecureJoinProgressListener()
                self.dcContext.lastErrorString = nil
                let chatId = self.dcContext.joinSecurejoin(qrCode: code)
                let errorString = self.dcContext.lastErrorString
                self.removeSecureJoinProgressListener()

                DispatchQueue.main.async {
                    self.progressAlert?.dismiss(animated: true, completion: nil)
                    if chatId != 0 {
                        self.showChat(chatId: chatId)
                    } else if errorString != nil {
                        self.showErrorAlert(error: errorString!)
                    }
                }
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

    private func addSecureJoinProgressListener() {
        let nc = NotificationCenter.default
        progressObserver = nc.addObserver(
            forName: dcNotificationSecureJoinerProgress,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self = self else { return }
            if let ui = notification.userInfo,
                ui["progress"] as? Int == 400,
                let contactId = ui["contact_id"] as? Int {
                self.progressAlert?.message = String.localizedStringWithFormat(
                    String.localized("qrscan_x_verified_introduce_myself"),
                    DcContact(id: contactId).nameNAddr
                )
            }
        }
    }

    private func removeSecureJoinProgressListener() {
        let nc = NotificationCenter.default
        if let observer = self.progressObserver {
            nc.removeObserver(observer)
        }
    }

}

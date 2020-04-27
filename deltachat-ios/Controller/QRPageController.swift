import UIKit
import DcCore

class QRPageController: UIPageViewController {

    weak var coordinator: QrViewCoordinator?

    private let dcContext: DcContext
    private var secureJoinObserver: Any?

    private var selectedIndex: Int = 0

    private lazy var qrSegmentControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [String.localized("qrshow_title"), String.localized("qrscan_title")])
        control.tintColor = DcColors.primary
        control.addTarget(self, action: #selector(qrSegmentControlChanged), for: .valueChanged)
        control.selectedSegmentIndex = 0
        return control
    }()

    private lazy var progressAlert: UIAlertController = {
        var title = String.localized("one_moment")+"\n\n"
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)

        let rect = CGRect(x: 0, y: 0, width: 25, height: 25)
        let activityIndicator = UIActivityIndicatorView(frame: rect)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.style = .gray

        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default, handler: { _ in
            self.dcContext.stopOngoingProcess()
            self.dismiss(animated: true, completion: nil)
        }))
        return alert
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

        let qrController = makeQrViewController()
        setViewControllers(
            [qrController],
            direction: .forward,
            animated: true,
            completion: nil
        )
    }

    // MARK: - actions
    @objc private func qrSegmentControlChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            let qrController = makeQrViewController()
            setViewControllers([qrController], direction: .reverse, animated: true, completion: nil)
        } else {
            let qrCodeReaderController = makeQRReader()
            setViewControllers([qrCodeReaderController], direction: .forward, animated: true, completion: nil)
        }
    }

    // MARK: - factory
    private func makeQrViewController() -> QrViewController {
        let controller = QrViewController(dcContext: dcContext)
        return controller
    }

    private func makeQRReader() -> QrCodeReaderController {
        let qrReader = QrCodeReaderController()
        qrReader.delegate = self
        return qrReader
    }
}

// MARK: - UIPageViewControllerDataSource, UIPageViewControllerDelegate
extension QRPageController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if viewController is QrViewController {
            return nil
        }
        return makeQrViewController()
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
extension QRPageController: QrCodeReaderDelegate {

    func handleQrCode(_ code: String) {
        self.processQrCode(code)
    }

    private func processQrCode(_ code: String) {
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
                self.coordinator?.showChat(chatId: chatId)
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
            self.showProgressAlert()
            // execute blocking secure join in background
            DispatchQueue.global(qos: .background).async {
                self.addSecureJoinProgressListener()
                self.dcContext.lastErrorString = nil
                let chatId = self.dcContext.joinSecurejoin(qrCode: code)
                let errorString = self.dcContext.lastErrorString
                self.removeSecureJoinProgressListener()

                DispatchQueue.main.async {
                    self.progressAlert.dismiss(animated: true, completion: nil)
                    if chatId != 0 {
                        self.coordinator?.showChat(chatId: chatId)
                    } else if errorString != nil {
                        self.showErrorAlert(error: errorString!)
                    }
                }
            }
        }))
        present(alert, animated: true, completion: nil)
    }

    private func showProgressAlert() {
        self.present(self.progressAlert, animated: true, completion: {
            let rect = CGRect(x: 10, y: 10, width: 20, height: 20)
            let progressView = UIActivityIndicatorView(frame: rect)
            progressView.tintColor = .blue
            progressView.startAnimating()
            progressView.translatesAutoresizingMaskIntoConstraints = false
            self.progressAlert.view.addSubview(progressView)
            self.progressAlert.view.addConstraints([
                progressView.constraintCenterXTo(self.progressAlert.view),
                progressView.constraintAlignTopTo(self.progressAlert.view, paddingTop: 45)
            ])
        })
    }

    private func showErrorAlert(error: String) {
        let alert = UIAlertController(title: String.localized("error"), message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
            alert.dismiss(animated: true, completion: nil)
        }))
    }

    private func addSecureJoinProgressListener() {
        let nc = NotificationCenter.default
        secureJoinObserver = nc.addObserver(
            forName: dcNotificationSecureJoinerProgress,
            object: nil,
            queue: nil
        ) { notification in
            print("secure join: ", notification)
            if let ui = notification.userInfo {
                if ui["progress"] as? Int == 400 {
                    if let contactId = ui["contact_id"] as? Int {
                        self.progressAlert.message = String.localizedStringWithFormat(
                            String.localized("qrscan_x_verified_introduce_myself"),
                            DcContact(id: contactId).nameNAddr)
                    }
                }
            }
        }
    }

    private func removeSecureJoinProgressListener() {
        let nc = NotificationCenter.default
        if let secureJoinObserver = self.secureJoinObserver {
            nc.removeObserver(secureJoinObserver)
        }
    }

}

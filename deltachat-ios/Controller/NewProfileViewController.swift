import Foundation
import UIKit

class NewProfileViewController: UITableViewController, QrCodeReaderDelegate {
    private let rowContact = 0
    private let rowQRCode = 1
    private let rowScanQR = 2

    weak var coordinator: ProfileCoordinator?
    let qrCodeReaderController = QrCodeReaderController()
    var secureJoinObserver: Any?
    var dcContext: DcContext
    var contact: DcContact? {
        // This is nil if we do not have an account setup yet
        if !DcConfig.configured {
            return nil
        }
        return DcContact(id: Int(DC_CONTACT_ID_SELF))
    }

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("pref_profile_info_headline")
        qrCodeReaderController.delegate = self
        tableView.separatorStyle = .none
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        switch row {
        case rowContact:
            return createContactCell()
        case rowQRCode:
            return createQRCodeCell()
        case rowScanQR:
            return createQRCodeScanCell()
        default:
            return UITableViewCell(style: .default, reuseIdentifier: nil)
        }
    }

    override func viewWillAppear(_: Bool) {
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = true
        }
    }

    override func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case rowContact:
            return 72
        case rowQRCode:
            return 225
        case rowScanQR:
            return 40
        default:
            return 10
        }
    }

    private lazy var progressAlert: UIAlertController = {
        let alert = UIAlertController(title: String.localized("one_moment"), message: "TESTMESSAGE", preferredStyle: .alert)

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

    private func showProgressAlert() {
        self.present(self.progressAlert, animated: true, completion: {
            let rect = CGRect(x: 10, y: 10, width: 20, height: 20)
            let progressView = UIActivityIndicatorView(frame: rect)
            progressView.tintColor = .blue
            progressView.startAnimating()
            self.progressAlert.view.addSubview(progressView)
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

    //QRCodeDelegate
    func handleQrCode(_ code: String) {
        //remove qr code scanner view
        if let ctrl = navigationController {
            ctrl.viewControllers.removeLast()
        }

        let qrParsed: DcLot = self.dcContext.checkQR(qrCode: code)
        let state = Int32(qrParsed.state)
        switch state {
        case DC_QR_ASK_VERIFYCONTACT:
            let nameAndAddress = DcContact(id: qrParsed.id).nameNAddr
            joinSecureJoin(alertMessage: String.localizedStringWithFormat(String.localized("qrscan_ask_fingerprint_ask_oob"), nameAndAddress), code: code)
        case DC_QR_ASK_VERIFYGROUP:
            if let group = qrParsed.text1?.replacingOccurrences(of: "+", with: " ") {
                joinSecureJoin(alertMessage: String.localizedStringWithFormat(String.localized("qrscan_ask_join_verified_group"), group), code: code)
            }
        default:
            let alertMessage = "QR code scanning for type " + String(state) + " is not yet implemented."
            let alert = UIAlertController(title: alertMessage,
                                          message: nil,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
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
                AppDelegate.lastErrorDuringConfig = nil
                let chatId = self.dcContext.joinSecurejoin(qrCode: code)
                let errorString = AppDelegate.lastErrorDuringConfig
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

    private func createContactCell() -> UITableViewCell {
        let cell = ContactCell(style: .default, reuseIdentifier: "contactCell")
        let bg = UIColor(red: 248 / 255, green: 248 / 255, blue: 255 / 255, alpha: 1.0)

        if let contact = self.contact {
            let name = DcConfig.displayname ?? contact.displayName
            cell.backgroundColor = bg
            cell.nameLabel.text = name
            cell.emailLabel.text = contact.email
            cell.darkMode = false
            if let img = contact.profileImage {
                cell.setImage(img)
            } else {
                cell.setBackupImage(name: name, color: contact.color)
            }
        } else {
            cell.nameLabel.text = String.localized("no_account_setup")
        }
        return cell
    }

    private func createQRCodeCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "qrCodeCell")
        let qrCode = createQRCodeView()
        let infolabel = createInfoLabel()

        cell.contentView.addSubview(qrCode)
        cell.contentView.addSubview(infolabel)
        cell.selectionStyle = .none

        let qrCodeConstraints = [qrCode.constraintAlignTopTo(cell.contentView, paddingTop: 25),
                                 qrCode.constraintCenterXTo(cell.contentView)]
        let infoLabelConstraints = [infolabel.constraintToBottomOf(qrCode, paddingTop: 25),
                                    infolabel.constraintAlignLeadingTo(cell.contentView, paddingLeading: 8),
                                    infolabel.constraintAlignTrailingTo(cell.contentView, paddingTrailing: 8)]
        cell.contentView.addConstraints(qrCodeConstraints)
        cell.contentView.addConstraints(infoLabelConstraints)
        return cell
    }

    private func createQRCodeScanCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "scanQR")
        let scanButton = createQRCodeScannerButton()
        cell.contentView.addSubview(scanButton)
        cell.selectionStyle = .none
        let scanButtonConstraints = [scanButton.constraintCenterXTo(cell.contentView),
                                     scanButton.constraintCenterYTo(cell.contentView)]
        cell.contentView.addConstraints(scanButtonConstraints)
        return cell
    }

    private func createInfoLabel() -> UIView {
        let label = UILabel.init()
        label.translatesAutoresizingMaskIntoConstraints = false
        if let contact = contact {
            label.text = String.localizedStringWithFormat(String.localized("qrshow_join_contact_hint"), contact.email)
        }
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }

    private func createQRCodeScannerButton() -> UIView {
        let btn = UIButton.init(type: UIButton.ButtonType.system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(String.localized("qrscan_title"), for: .normal)
        btn.addTarget(self, action: #selector(self.openQRCodeScanner), for: .touchUpInside)
        return btn
    }

    @objc func openQRCodeScanner() {
        if let ctrl = navigationController {
            ctrl.pushViewController(qrCodeReaderController, animated: true)
        }
    }

    private func createQRCodeView() -> UIView {
        let width: CGFloat = 130
        let frame = CGRect(origin: .zero, size: .init(width: width, height: width))
        let imageView = QRCodeView(frame: frame)
        if let qrCode = dcContext.getSecurejoinQr(chatId: 0) {
            imageView.generateCode(
                qrCode,
                foregroundColor: .darkText,
                backgroundColor: .white
            )
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: width).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: width).isActive = true
        return imageView
    }

    func displayNewChat(contactId: Int) {
        let chatId = dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))
        let chatVC = ChatViewController(dcContext: dcContext, chatId: Int(chatId))

        chatVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(chatVC, animated: true)
    }
}

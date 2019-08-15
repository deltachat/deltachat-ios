import Foundation
import UIKit

class NewProfileViewController: UIViewController, QrCodeReaderDelegate {

    weak var coordinator: ProfileCoordinator?
    let qrCodeReaderController = QrCodeReaderController()
    var secureJoinObserver: Any?
    var dcContext: DcContext

    var contactCell: UIView?
    var infoLabel: UIView?
    var qrCode: UIView?
    var qrCodeScanner: UIView?

    var contactCellConstraints: [NSLayoutConstraint] = []
    var infoLabelConstraints: [NSLayoutConstraint] = []
    var qrCodeConstraints: [NSLayoutConstraint] = []
    var qrCodeScannerConstraints: [NSLayoutConstraint] = []

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    var contact: DCContact? {
        // This is nil if we do not have an account setup yet
        if !DCConfig.configured {
            return nil
        }
        return DCContact(id: Int(DC_CONTACT_ID_SELF))
    }

    var fingerprint: String? {
        if !DCConfig.configured {
            return nil
        }
        return dcContext.getSecurejoinQr(chatId: 0)
    }

    override func loadView() {
        let view = UIView()
        view.backgroundColor = UIColor.white
        self.view = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("my_profile")
        qrCodeReaderController.delegate = self
        self.edgesForExtendedLayout = []

        initViews()

        if UIDevice.current.orientation.isLandscape {
            setupLandscapeConstraints()
        } else {
            setupPortraitConstraints()
        }

    }

    private func initViews() {
        contactCell = createContactCell()
        infoLabel = createInfoLabel()
        qrCode = createQRCodeView()
        qrCodeScanner = createQRCodeScannerButton()
        self.view.addSubview(contactCell!)
        self.view.addSubview(qrCode!)
        self.view.addSubview(infoLabel!)
        self.view.addSubview(qrCodeScanner!)
    }

    private func applyConstraints() {
        self.view.addConstraints(contactCellConstraints)
        self.view.addConstraints(qrCodeConstraints)
        self.view.addConstraints(infoLabelConstraints)
        self.view.addConstraints(qrCodeScannerConstraints)
    }

    private func removeConstraints() {
        self.view.removeConstraints(contactCellConstraints)
        self.view.removeConstraints(qrCodeConstraints)
        self.view.removeConstraints(infoLabelConstraints)
        self.view.removeConstraints(qrCodeScannerConstraints)
    }

    func setupPortraitConstraints() {
        removeConstraints()
        contactCellConstraints = [contactCell!.constraintAlignTopTo(self.view),
                                  contactCell!.constraintAlignLeadingTo(self.view),
                                  contactCell!.constraintAlignTrailingTo(self.view)]
        qrCodeScannerConstraints = [qrCodeScanner!.constraintAlignBottomTo(self.view, paddingBottom: 25),
                                    qrCodeScanner!.constraintCenterXTo(self.view)]
        qrCodeConstraints = [qrCode!.constraintCenterYTo(self.view),
                             qrCode!.constraintCenterYTo(self.view, paddingY: -25),
                             qrCode!.constraintCenterXTo(self.view)]
        infoLabelConstraints = [infoLabel!.constraintToBottomOf(qrCode!, paddingTop: 25),
                                infoLabel!.constraintAlignLeadingTo(self.view, paddingLeading: 8),
                                infoLabel!.constraintAlignTrailingTo(self.view, paddingTrailing: 8)]
        applyConstraints()
    }

    func setupLandscapeConstraints() {
        removeConstraints()
        contactCellConstraints = [contactCell!.constraintAlignTopTo(self.view),
                                  contactCell!.constraintAlignLeadingTo(self.view),
                                  contactCell!.constraintAlignTrailingTo(self.view)]
        qrCodeScannerConstraints = [qrCodeScanner!.constraintToTrailingOf(qrCode!, paddingLeading: 50),
                                    qrCodeScanner!.constraintAlignTrailingTo(self.view, paddingTrailing: 50),
                                    qrCodeScanner!.constraintAlignBottomTo(qrCode!)]
        qrCodeConstraints = [qrCode!.constraintToBottomOf(contactCell!, paddingTop: 25),
                             qrCode!.constraintAlignLeadingTo(self.view, paddingLeading: 50)]
        infoLabelConstraints = [infoLabel!.constraintToBottomOf(contactCell!, paddingTop: 25),
                                infoLabel!.constraintToTrailingOf(qrCode!, paddingLeading: 50),
                                infoLabel!.constraintAlignTrailingTo(self.view, paddingTrailing: 50)]
        applyConstraints()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if UIDevice.current.orientation.isLandscape {
            setupLandscapeConstraints()
        } else {
            setupPortraitConstraints()
        }
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
                            DCContact(id: contactId).nameNAddr)
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
        let nameAndAddress = DCContact(id: qrParsed.id).nameNAddr
        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("qrscan_ask_fingerprint_ask_oob"), nameAndAddress),
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
        if let fingerprint = self.fingerprint {
            let width: CGFloat = 130

            let frame = CGRect(origin: .zero, size: .init(width: width, height: width))
            let imageView = QRCodeView(frame: frame)
            imageView.generateCode(
                fingerprint,
                foregroundColor: .darkText,
                backgroundColor: .white
            )
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: width).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: width).isActive = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            return imageView
        }
        return UIImageView()
    }

    private func createContactCell() -> UIView {
        let bg = UIColor(red: 248 / 255, green: 248 / 255, blue: 255 / 255, alpha: 1.0)

        let profileView = ProfileView(frame: CGRect())
        if let contact = self.contact {
            let name = DCConfig.displayname ?? contact.name
            profileView.setBackgroundColor(bg)
            profileView.nameLabel.text = name
            profileView.emailLabel.text = contact.email
            profileView.darkMode = false
            if let img = contact.profileImage {
                profileView.setImage(img)
            } else {
                profileView.setBackupImage(name: name, color: contact.color)
            }
        } else {
            profileView.nameLabel.text = String.localized("no_account_setup")
        }

        return profileView
    }

    override func viewWillAppear(_: Bool) {
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    func displayNewChat(contactId: Int) {
        let chatId = dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))
        let chatVC = ChatViewController(dcContext: dcContext, chatId: Int(chatId))

        chatVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(chatVC, animated: true)
    }
}

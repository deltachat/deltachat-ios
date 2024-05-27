import UIKit
import DcCore

class WelcomeViewController: UIViewController, ProgressAlertHandler {
    private var dcContext: DcContext
    private let dcAccounts: DcAccounts
    private let accountCode: String?
    private var backupProgressObserver: NSObjectProtocol?
    var progressObserver: NSObjectProtocol?
    var onProgressSuccess: VoidFunction?
    private var securityScopedResource: NSURL?

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private lazy var welcomeView: WelcomeContentView = {
        let view = WelcomeContentView()
        view.onSignUp = { [weak self] in
            guard let self else { return }
            let controller = InstantOnboardingViewController(dcAccounts: dcAccounts)
            navigationController?.pushViewController(controller, animated: true)
        }
        view.onLogIn = { [weak self] in
            guard let self else { return }
            let alert = UIAlertController(title: String.localized("onboarding_alternative_logins"), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("multidevice_receiver_title"), style: .default, handler: addAsSecondDevice(_:)))
            alert.addAction(UIAlertAction(title: String.localized("import_backup_title"), style: .default, handler: restoreBackup(_:)))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
            present(alert, animated: true, completion: nil)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var canCancel: Bool = {
        // "cancel" removes selected unconfigured account, so there needs to be at least one other account
        return dcAccounts.getAll().count >= 2
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        return UIBarButtonItem(title: String.localized("cancel"), style: .plain, target: self, action: #selector(cancelAccountCreation))
    }()

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(dcContext: dcContext, navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    private var qrCodeReader: QrCodeReaderController?
    weak var progressAlert: UIAlertController?

    init(dcAccounts: DcAccounts, accountCode: String? = nil) {
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()
        self.accountCode = accountCode
        super.init(nibName: nil, bundle: nil)
        self.navigationItem.title = String.localized(canCancel ? "add_account" : "welcome_desktop")
        onProgressSuccess = { [weak self] in
            guard let self else { return }
            let profileInfoController = ProfileInfoViewController(context: self.dcContext)
            profileInfoController.onClose = {
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.reloadDcContext()
                }
            }
            self.navigationController?.setViewControllers([profileInfoController], animated: true)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
        if canCancel {
            navigationItem.leftBarButtonItem = cancelButton
        }
        if let accountCode {
            handleQrCode(accountCode)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        welcomeView.minContainerHeight = view.frame.height - view.safeAreaInsets.top
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        welcomeView.minContainerHeight = size.height - view.safeAreaInsets.top
     }

    override func viewDidDisappear(_ animated: Bool) {
        if let observer = self.progressObserver {
            NotificationCenter.default.removeObserver(observer)
            self.progressObserver = nil
        }
        removeBackupProgressObserver()
    }

    private func removeBackupProgressObserver() {
        if let backupProgressObserver = self.backupProgressObserver {
            NotificationCenter.default.removeObserver(backupProgressObserver)
            self.backupProgressObserver = nil
        }
    }

    // MARK: - setup
    private func setupSubviews() {

        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(welcomeView)

        let frameGuide = scrollView.frameLayoutGuide
        let contentGuide = scrollView.contentLayoutGuide

        frameGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        frameGuide.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        frameGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        frameGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true

        contentGuide.leadingAnchor.constraint(equalTo: welcomeView.leadingAnchor).isActive = true
        contentGuide.topAnchor.constraint(equalTo: welcomeView.topAnchor).isActive = true
        contentGuide.trailingAnchor.constraint(equalTo: welcomeView.trailingAnchor).isActive = true
        contentGuide.bottomAnchor.constraint(equalTo: welcomeView.bottomAnchor).isActive = true

        // this enables vertical scrolling
        frameGuide.widthAnchor.constraint(equalTo: contentGuide.widthAnchor).isActive = true
    }

    // MARK: - actions

    private func addAsSecondDevice(_ action: UIAlertAction) {
        let qrReader = QrCodeReaderController(title: String.localized("multidevice_receiver_title"),
                    addHints: "➊ " + String.localized("multidevice_same_network_hint") + "\n\n"
                        +     "➋ " + String.localized("multidevice_open_settings_on_other_device") + "\n\n"
                        +     String.localized("multidevice_experimental_hint"),
                    showTroubleshooting: true)
        qrReader.delegate = self
        qrCodeReader = qrReader
        navigationController?.pushViewController(qrReader, animated: true)
    }

    private func createAccountFromQRCode(qrCode: String) {
        if dcAccounts.getSelected().isConfigured() {
            UserDefaults.standard.setValue(dcAccounts.getSelected().id, forKey: Constants.Keys.lastSelectedAccountKey)
            _ = dcAccounts.add()
        }
        let accountId = dcAccounts.getSelected().id

        if accountId != 0 {
            dcContext = dcAccounts.get(id: accountId)
            addProgressAlertListener(dcAccounts: self.dcAccounts,
                                     progressName: eventConfigureProgress,
                                     onSuccess: self.handleLoginSuccess)
            showProgressAlert(title: String.localized("login_header"), dcContext: self.dcContext)
            DispatchQueue.global().async { [weak self] in
                guard let self else { return }
                let success = self.dcContext.setConfigFromQR(qrCode: qrCode)
                DispatchQueue.main.async {
                    if success {
                        self.dcAccounts.stopIo()
                        self.dcContext.configure()
                    } else {
                        self.updateProgressAlert(error: self.dcContext.lastErrorString,
                                                 completion: self.accountCode != nil ? self.cancelAccountCreation : nil)
                    }
                }
            }
        }
    }

    private func handleLoginSuccess() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        if !UserDefaults.standard.bool(forKey: "notifications_disabled") {
            appDelegate.registerForNotifications()
        }
        onProgressSuccess?()
    }

    private func handleBackupRestoreSuccess() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        if !UserDefaults.standard.bool(forKey: "notifications_disabled") {
            appDelegate.registerForNotifications()
        }

        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.reloadDcContext()
        }
    }

    @objc private func cancelAccountCreation() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        // take a bit care on account removal:
        // remove only openend and unconfigured and make sure, there is another account
        // (normally, both checks are not needed, however, some resilience wrt future program-flow-changes seems to be reasonable here)
        let selectedAccount = dcAccounts.getSelected()
        if selectedAccount.isOpen() && !selectedAccount.isConfigured() {
            _ = dcAccounts.remove(id: selectedAccount.id)
            KeychainManager.deleteAccountSecret(id: selectedAccount.id)
            if self.dcAccounts.getAll().isEmpty {
                _ = self.dcAccounts.add()
            }
        }

        let lastSelectedAccountId = UserDefaults.standard.integer(forKey: Constants.Keys.lastSelectedAccountKey)
        if lastSelectedAccountId != 0 {
            _ = dcAccounts.select(id: lastSelectedAccountId)
            dcAccounts.startIo()
        }

        appDelegate.reloadDcContext()
    }

    private func restoreBackup(_ action: UIAlertAction) {
        if dcContext.isConfigured() {
            return
        }
        mediaPicker?.showDocumentLibrary(selectFolder: true)
    }

    private func importBackup(at filepath: String) {
        logger.info("restoring backup: \(filepath)")
        showProgressAlert(title: String.localized("import_backup_title"), dcContext: dcContext)
        dcAccounts.stopIo()
        dcContext.imex(what: DC_IMEX_IMPORT_BACKUP, directory: filepath)
    }

    private func addProgressHudBackupListener(importByFile: Bool) {
        UIApplication.shared.isIdleTimerDisabled = true
        backupProgressObserver = NotificationCenter.default.addObserver(
            forName: eventImexProgress,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self else { return }
            if let ui = notification.userInfo {
                if let error = ui["error"] as? Bool, error {
                    UIApplication.shared.isIdleTimerDisabled = false
                    if self.dcContext.isConfigured() {
                        let accountId = self.dcContext.id
                        _ = self.dcAccounts.remove(id: accountId)
                        KeychainManager.deleteAccountSecret(id: accountId)
                        _ = self.dcAccounts.add()
                        self.dcContext = self.dcAccounts.getSelected()
                        self.navigationItem.title = String.localized(self.canCancel ? "add_account" : "welcome_desktop")
                    }
                    self.updateProgressAlert(error: ui["errorMessage"] as? String)
                    self.stopAccessingSecurityScopedResource()
                    self.removeBackupProgressObserver()
                } else if let done = ui["done"] as? Bool, done {
                    UIApplication.shared.isIdleTimerDisabled = false
                    self.dcAccounts.startIo()
                    self.updateProgressAlertSuccess(completion: self.handleBackupRestoreSuccess)
                    self.stopAccessingSecurityScopedResource()
                } else if importByFile {
                    self.updateProgressAlertValue(value: ui["progress"] as? Int)
                } else {
                    guard let permille = ui["progress"] as? Int else { return }
                    var statusLineText = ""
                    if permille <= 100 {
                        statusLineText = String.localized("preparing_account")
                    } else if permille <= 950 {
                        let percent = ((permille-100)*100)/850
                        statusLineText = String.localized("transferring") + " \(percent)%"
                    } else {
                        statusLineText = "Finishing..." // range not used, should not happen
                    }
                    self.updateProgressAlert(message: statusLineText)
                }
            }
        }
    }
}

// MARK: - QrCodeReaderDelegate
extension WelcomeViewController: QrCodeReaderDelegate {
    func handleQrCode(_ code: String) {
        let lot = dcContext.checkQR(qrCode: code)
        if let domain = lot.text1, lot.state == DC_QR_ACCOUNT {
            let title = String.localizedStringWithFormat(
                String.localized(dcAccounts.getAll().count > 1 ? "qraccount_ask_create_and_login_another" : "qraccount_ask_create_and_login"),
                domain)
            confirmQrAccountAlert(title: title, qrCode: code)
        } else if let email = lot.text1, lot.state == DC_QR_LOGIN {
            let title = String.localizedStringWithFormat(
                String.localized(dcAccounts.getAll().count > 1 ? "qrlogin_ask_login_another" : "qrlogin_ask_login"),
                email)
            confirmQrAccountAlert(title: title, qrCode: code)
        } else if lot.state == DC_QR_BACKUP {
             confirmSetupNewDevice(qrCode: code)
        } else {
            qrErrorAlert()
        }
    }

    private func confirmQrAccountAlert(title: String, qrCode: String) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)

        let okAction = UIAlertAction(
            title: String.localized("ok"),
            style: .default,
            handler: { [weak self] _ in
                guard let self else { return }
                self.dismissQRReader()
                self.createAccountFromQRCode(qrCode: qrCode)
            }
        )

        let qrCancelAction = UIAlertAction(
            title: String.localized("cancel"),
            style: .cancel,
            handler: { [weak self] _ in
                guard let self else { return }
                self.dismissQRReader()
                // if an injected accountCode exists, the WelcomeViewController was only opened to handle that
                // cancelling the action should also dismiss the whole controller
                if self.accountCode != nil {
                    self.cancelAccountCreation()
                }
            }
        )

        alert.addAction(okAction)
        alert.addAction(qrCancelAction)
        if qrCodeReader != nil {
            qrCodeReader?.present(alert, animated: true)
        } else {
            self.present(alert, animated: true)
        }
    }

    private func confirmSetupNewDevice(qrCode: String) {
        triggerLocalNetworkPrivacyAlert()
        let alert = UIAlertController(title: String.localized("multidevice_receiver_title"),
                                      message: String.localized("multidevice_receiver_scanning_ask"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(
             title: String.localized("ok"),
             style: .default,
             handler: { [weak self] _ in
                 guard let self else { return }
                 if self.dcAccounts.getSelected().isConfigured() {
                     UserDefaults.standard.setValue(self.dcAccounts.getSelected().id, forKey: Constants.Keys.lastSelectedAccountKey)
                     _ = self.dcAccounts.add()
                 }
                 let accountId = self.dcAccounts.getSelected().id
                 if accountId != 0 {
                     self.dcContext = self.dcAccounts.get(id: accountId)
                     self.dismissQRReader()
                     self.addProgressHudBackupListener(importByFile: false)
                     self.showProgressAlert(title: String.localized("multidevice_receiver_title"), dcContext: self.dcContext)
                     self.dcAccounts.stopIo()
                     DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                         guard let self else { return }
                         logger.info("##### receiveBackup() with qr: \(qrCode)")
                         let res = self.dcContext.receiveBackup(qrCode: qrCode)
                         logger.info("##### receiveBackup() done with result: \(res)")
                     }
                 }
             }
        ))
        alert.addAction(UIAlertAction(
            title: String.localized("cancel"),
            style: .cancel,
            handler: { [weak self] _ in
                self?.dcContext.stopOngoingProcess()
                self?.dismissQRReader()
            }
        ))
        if let qrCodeReader {
            qrCodeReader.present(alert, animated: true)
        } else {
            self.present(alert, animated: true)
        }
    }

    private func qrErrorAlert() {
        let title = String.localized("qraccount_qr_code_cannot_be_used")
        let alert = UIAlertController(title: title, message: dcContext.lastErrorString, preferredStyle: .alert)
        let okAction = UIAlertAction(
            title: String.localized("ok"),
            style: .default,
            handler: { [weak self] _ in
                guard let self else { return }
                if self.accountCode != nil {
                    // if an injected accountCode exists, the WelcomeViewController was only opened to handle that
                    // if the action failed the whole controller should be dismissed
                    self.cancelAccountCreation()
                } else {
                    self.qrCodeReader?.startSession()
                }
            }
        )
        alert.addAction(okAction)
        qrCodeReader?.present(alert, animated: true, completion: nil)
    }

    private func dismissQRReader() {
        self.navigationController?.popViewController(animated: true)
        self.qrCodeReader = nil
    }

    private func stopAccessingSecurityScopedResource() {
        self.securityScopedResource?.stopAccessingSecurityScopedResource()
        self.securityScopedResource = nil
    }
}

// MARK: - WelcomeContentView
class WelcomeContentView: UIView {

    var onSignUp: VoidFunction?
    var onLogIn: VoidFunction?

    var minContainerHeight: CGFloat = 0 {
        didSet {
            containerMinHeightConstraint.constant = minContainerHeight
            logoHeightConstraint.constant = calculateLogoHeight()
        }
    }

    private lazy var containerMinHeightConstraint: NSLayoutConstraint = {
        return container.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
    }()

    private lazy var logoHeightConstraint: NSLayoutConstraint = {
        return logoView.heightAnchor.constraint(equalToConstant: 0)
    }()

    private var container = UIView()
    private var logoView = UIImageView(image: UIImage(named: "dc_logo"))

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = String.localized("welcome_chat_over_email")
        label.textColor = DcColors.grayTextColor
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: .title1)
        return label
    }()

    private lazy var buttonStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [signUpButton, logInButton])
        stack.axis = .vertical
        stack.spacing = 15
        return stack
    }()

    private lazy var signUpButton: UIButton = {
        let button = UIButton(type: .roundedRect)
        let title = String.localized("onboarding_create_instant_account")
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 15, bottom: 8, right: 15)
        button.layer.cornerRadius = 5
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(signUpButtonPressed(_:)), for: .touchUpInside)
        return button
    }()

    private lazy var logInButton: UIButton = {
        let button = UIButton()
        let title = String.localized("onboarding_alternative_logins")
        button.setTitleColor(UIColor.systemBlue, for: .normal)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.addTarget(self, action: #selector(logInButtonPressed(_:)), for: .touchUpInside)
        return button
    }()

    private let defaultSpacing: CGFloat = 20

    init() {
        super.init(frame: .zero)
        setupSubviews()
        backgroundColor = DcColors.defaultBackgroundColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - setup
    private func setupSubviews() {
        addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false

        container.topAnchor.constraint(equalTo: topAnchor).isActive = true
        container.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        container.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.75).isActive = true
        container.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 0).isActive = true

        containerMinHeightConstraint.isActive = true

        _ = [logoView, titleLabel].map {
            addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        let bottomLayoutGuide = UILayoutGuide()
        container.addLayoutGuide(bottomLayoutGuide)
        bottomLayoutGuide.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
        bottomLayoutGuide.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.45).isActive = true

        titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
        titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true
        titleLabel.topAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor).isActive = true
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)

        logoView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -defaultSpacing).isActive = true
        logoView.centerXAnchor.constraint(equalTo: container.centerXAnchor).isActive = true
        logoHeightConstraint.constant = calculateLogoHeight()
        logoHeightConstraint.isActive = true
        logoView.widthAnchor.constraint(equalTo: logoView.heightAnchor).isActive = true

        let logoTopAnchor = logoView.topAnchor.constraint(equalTo: container.topAnchor, constant: 20)   // this will allow the container to grow in height
        logoTopAnchor.priority = .defaultLow
        logoTopAnchor.isActive = true

        let buttonContainerGuide = UILayoutGuide()
        container.addLayoutGuide(buttonContainerGuide)
        buttonContainerGuide.topAnchor.constraint(equalTo: titleLabel.bottomAnchor).isActive = true
        buttonContainerGuide.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true

        signUpButton.setContentHuggingPriority(.defaultHigh, for: .vertical)

        container.addSubview(buttonStack)
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.centerXAnchor.constraint(equalTo: container.centerXAnchor).isActive = true
        buttonStack.centerYAnchor.constraint(equalTo: buttonContainerGuide.centerYAnchor).isActive = true

        let buttonStackTopAnchor = buttonStack.topAnchor.constraint(equalTo: buttonContainerGuide.topAnchor, constant: defaultSpacing)
        // this will allow the container to grow in height
        let buttonStackBottomAnchor = buttonStack.bottomAnchor.constraint(equalTo: buttonContainerGuide.bottomAnchor, constant: -50)

        _ = [buttonStackTopAnchor, buttonStackBottomAnchor].map {
            $0.priority = .defaultLow
            $0.isActive = true
        }
    }

    private func calculateLogoHeight() -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return  UIApplication.shared.statusBarOrientation.isLandscape ? UIScreen.main.bounds.height * 0.5 : UIScreen.main.bounds.width * 0.5
        } else {
            return 275
        }
    }

    // MARK: - actions
    @objc private func signUpButtonPressed(_ sender: UIButton) {
        onSignUp?()
    }

    @objc private func logInButtonPressed(_ sender: UIButton) {
        onLogIn?()
    }
}

extension WelcomeViewController: MediaPickerDelegate {
    func onDocumentSelected(url: NSURL) {
        // ensure we can access folders outside of the app's sandbox
        let isSecurityScopedResource = url.startAccessingSecurityScopedResource()
        if isSecurityScopedResource {
            securityScopedResource = url
        }

        if let selectedBackupFilePath = url.relativePath {
            addProgressHudBackupListener(importByFile: true)
            importBackup(at: selectedBackupFilePath)
        } else {
            stopAccessingSecurityScopedResource()
        }
    }
}

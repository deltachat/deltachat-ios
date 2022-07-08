import UIKit
import DcCore

class WelcomeViewController: UIViewController, ProgressAlertHandler {
    private var dcContext: DcContext
    private let dcAccounts: DcAccounts
    private var backupProgressObserver: NSObjectProtocol?
    var progressObserver: NSObjectProtocol?
    var onProgressSuccess: VoidFunction?

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private lazy var welcomeView: WelcomeContentView = {
        let view = WelcomeContentView()
        view.onLogin = { [weak self] in
            guard let self = self else { return }
            self.showAccountSetupController()
        }
        view.onScanQRCode  = { [weak self] in
            guard let self = self else { return }
            let qrReader = QrCodeReaderController()
            qrReader.delegate = self
            self.qrCodeReader = qrReader
            self.navigationController?.pushViewController(qrReader, animated: true)
        }
        view.onImportBackup = { [weak self] in
            guard let self = self else { return }
            self.restoreBackup()
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var canCancel: Bool = {
        // "cancel" removes selected unconfigured account, so there needs to be at least one other account
        return dcAccounts.getAll().count >= 2
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        return UIBarButtonItem(title: String.localized("cancel"), style: .plain, target: self, action: #selector(cancelButtonPressed))
    }()

    private lazy var moreButton: UIBarButtonItem = {
        let image: UIImage?
        if #available(iOS 13.0, *) {
            image = UIImage(systemName: "ellipsis.circle")
        } else {
            image = UIImage(named: "ic_more")
        }
        return UIBarButtonItem(image: image,
                               style: .plain,
                               target: self,
                               action: #selector(moreButtonPressed))
    }()

    private var qrCodeReader: QrCodeReaderController?
    weak var progressAlert: UIAlertController?

    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()
        super.init(nibName: nil, bundle: nil)
        self.navigationItem.title = String.localized(canCancel ? "add_account" : "welcome_desktop")
        onProgressSuccess = { [weak self] in
            guard let self = self else { return }
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
        navigationItem.rightBarButtonItem = moreButton
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
        let nc = NotificationCenter.default
        if let observer = self.progressObserver {
            nc.removeObserver(observer)
            self.progressObserver = nil
        }
        if let backupProgressObserver = self.backupProgressObserver {
            nc.removeObserver(backupProgressObserver)
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

    private func createAccountFromQRCode(qrCode: String) {
        if dcAccounts.getSelected().isConfigured() {
            UserDefaults.standard.setValue(dcAccounts.getSelected().id, forKey: Constants.Keys.lastSelectedAccountKey)

            // FIXME: what do we want to do with QR-Code created accounts? For now: adding an unencrypted account
            // ensure we're configuring on an empty new account
            _ = dcAccounts.add()
        }
        let accountId = dcAccounts.getSelected().id

        if accountId != 0 {
            self.dcContext = dcAccounts.get(id: accountId)
            let success = dcContext.setConfigFromQR(qrCode: qrCode)
            if success {
                addProgressAlertListener(dcAccounts: dcAccounts, progressName: dcNotificationConfigureProgress, onSuccess: handleLoginSuccess)
                showProgressAlert(title: String.localized("login_header"), dcContext: dcContext)
                dcAccounts.stopIo()
                dcContext.configure()
            } else {
                accountCreationErrorAlert()
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

    private func accountCreationErrorAlert() {
        let title = dcContext.lastErrorString
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default))
        present(alert, animated: true)
    }

    @objc private func moreButtonPressed() {
        let alert = UIAlertController(title: "Encrypted Account (experimental)",
                                      message: "Do you want to encrypt your account database? This cannot be undone.",
                                      preferredStyle: .safeActionSheet)
        let encryptedAccountAction = UIAlertAction(title: "Create encrypted account", style: .default, handler: switchToEncrypted(_:))
        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .destructive, handler: nil)
        alert.addAction(encryptedAccountAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }

    private func switchToEncrypted(_ action: UIAlertAction) {
        let lastContextId = dcAccounts.getSelected().id
        let newContextId = dcAccounts.addClosedAccount()
        _ = dcAccounts.remove(id: lastContextId)
        _ = dcAccounts.select(id: newContextId)
        let selected = dcAccounts.getSelected()
        do {
            let secret = try KeychainManager.getAccountSecret(accountID: selected.id)
            guard selected.open(passphrase: secret) else {
                logger.error("Failed to open account database for account \(selected.id)")
                return
            }
            showAccountSetupController()
        } catch KeychainError.unhandledError(let message, let status) {
            logger.error("Keychain error. Failed to create encrypted account. \(message). Error status: \(status)")
        } catch {
            logger.error("Keychain error. Failed to create encrypted account.")
        }
    }

    private func showAccountSetupController() {
        let accountSetupController = AccountSetupController(dcAccounts: self.dcAccounts, editView: false)
        accountSetupController.onLoginSuccess = {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.reloadDcContext()
            }
        }
        self.navigationController?.pushViewController(accountSetupController, animated: true)
    }

    @objc private func cancelButtonPressed() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        // take a bit care on account removal:
        // remove only openend and unconfigured and make sure, there is another account
        // (normally, both checks are not needed, however, some resilience wrt future program-flow-changes seems to be reasonable here)
        let selectedAccount = dcAccounts.getSelected()
        if selectedAccount.isOpen() && !selectedAccount.isConfigured() {
            _ = dcAccounts.remove(id: selectedAccount.id)
            if self.dcAccounts.getAll().isEmpty {
                _ = self.dcAccounts.add()
            }
        }

        let lastSelectedAccountId = UserDefaults.standard.integer(forKey: Constants.Keys.lastSelectedAccountKey)
        if lastSelectedAccountId != 0 {
            _ = dcAccounts.select(id: lastSelectedAccountId)
        }

        appDelegate.reloadDcContext()
    }

    private func restoreBackup() {
        logger.info("restoring backup")
        if dcContext.isConfigured() {
            return
        }
        addProgressHudBackupListener()
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if !documents.isEmpty {
            logger.info("looking for backup in: \(documents[0])")

            if let file = dcContext.imexHasBackup(filePath: documents[0]) {
                logger.info("restoring backup: \(file)")
                showProgressAlert(title: String.localized("import_backup_title"), dcContext: dcContext)
                dcAccounts.stopIo()
                dcContext.imex(what: DC_IMEX_IMPORT_BACKUP, directory: file)
            } else {
                let alert = UIAlertController(
                    title: String.localized("import_backup_title"),
                    message: String.localizedStringWithFormat(
                        String.localized("import_backup_no_backup_found"),
                        "➔ Mac-Finder or iTunes ➔ iPhone ➔ " + String.localized("files") + " ➔ Delta Chat"), // iTunes was used up to Maverick 10.4
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String.localized("ok"), style: .cancel))
                present(alert, animated: true)
            }
        } else {
            logger.error("no documents directory found")
        }
    }

    private func addProgressHudBackupListener() {
        let nc = NotificationCenter.default
        backupProgressObserver = nc.addObserver(
            forName: dcNotificationImexProgress,
            object: nil,
            queue: nil
        ) { notification in
            if let ui = notification.userInfo {
                if let error = ui["error"] as? Bool, error {
                    self.dcAccounts.startIo()
                    self.updateProgressAlert(error: ui["errorMessage"] as? String)
                } else if let done = ui["done"] as? Bool, done {
                    self.dcAccounts.startIo()
                    self.updateProgressAlertSuccess(completion: self.handleBackupRestoreSuccess)
                } else {
                    self.updateProgressAlertValue(value: ui["progress"] as? Int)
                }
            }
        }
    }
}

extension WelcomeViewController: QrCodeReaderDelegate {
    func handleQrCode(_ code: String) {
        let lot = dcContext.checkQR(qrCode: code)
        if let domain = lot.text1, lot.state == DC_QR_ACCOUNT {
            confirmAccountCreationAlert(accountDomain: domain, qrCode: code)
        } else {
            qrErrorAlert()
        }
    }

    private func confirmAccountCreationAlert(accountDomain domain: String, qrCode: String) {
        let title = String.localizedStringWithFormat(String.localized("qraccount_ask_create_and_login"), domain)
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)

        let okAction = UIAlertAction(
            title: String.localized("ok"),
            style: .default,
            handler: { [weak self] _ in
                guard let self = self else { return }
                self.dismissQRReader()
                self.createAccountFromQRCode(qrCode: qrCode)
            }
        )

        let qrCancelAction = UIAlertAction(
            title: String.localized("cancel"),
            style: .cancel,
            handler: { [weak self] _ in
                self?.dismissQRReader()
            }
        )

        alert.addAction(okAction)
        alert.addAction(qrCancelAction)
        qrCodeReader?.present(alert, animated: true)
    }

    private func qrErrorAlert() {
        let title = String.localized("qraccount_qr_code_cannot_be_used")
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        let okAction = UIAlertAction(
            title: String.localized("ok"),
            style: .default,
            handler: { [weak self] _ in
                self?.qrCodeReader?.startSession()
            }
        )
        alert.addAction(okAction)
        qrCodeReader?.present(alert, animated: true, completion: nil)
    }

    private func dismissQRReader() {
        self.navigationController?.popViewController(animated: true)
        self.qrCodeReader = nil
    }
}

// MARK: - WelcomeContentView
class WelcomeContentView: UIView {

    var onLogin: VoidFunction?
    var onScanQRCode: VoidFunction?
    var onImportBackup: VoidFunction?

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

    private var logoView: UIImageView = {
        let image = #imageLiteral(resourceName: "background_intro")
        let view = UIImageView(image: image)
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = String.localized("welcome_chat_over_email")
        label.textColor = DcColors.grayTextColor
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        return label
    }()

    private lazy var buttonStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [loginButton, qrCodeButton, importBackupButton])
        stack.axis = .vertical
        stack.spacing = 15
        return stack
    }()

    private lazy var loginButton: UIButton = {
        let button = UIButton(type: .roundedRect)
        let title = String.localized("login_header").uppercased()
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = DcColors.primary
        let insets = button.contentEdgeInsets
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 15, bottom: 8, right: 15)
        button.layer.cornerRadius = 5
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(loginButtonPressed(_:)), for: .touchUpInside)
        return button
    }()

    private lazy var qrCodeButton: UIButton = {
        let button = UIButton()
        let title = String.localized("scan_invitation_code")
        button.setTitleColor(UIColor.systemBlue, for: .normal)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: #selector(qrCodeButtonPressed(_:)), for: .touchUpInside)
        return button
    }()

    private lazy var importBackupButton: UIButton = {
        let button = UIButton()
        let title = String.localized("import_backup_title")
        button.setTitleColor(UIColor.systemBlue, for: .normal)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: #selector(importBackupButtonPressed(_:)), for: .touchUpInside)
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

        loginButton.setContentHuggingPriority(.defaultHigh, for: .vertical)

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
            return  UIApplication.shared.statusBarOrientation.isLandscape ? UIScreen.main.bounds.height * 0.5 : UIScreen.main.bounds.width * 0.75
        } else {
            return 275
        }
    }

    // MARK: - actions
     @objc private func loginButtonPressed(_ sender: UIButton) {
         onLogin?()
     }

     @objc private func qrCodeButtonPressed(_ sender: UIButton) {
         onScanQRCode?()
     }

     @objc private func importBackupButtonPressed(_ sender: UIButton) {
         onImportBackup?()
     }
}

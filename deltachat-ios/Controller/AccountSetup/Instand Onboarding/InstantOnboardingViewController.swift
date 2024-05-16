import UIKit
import DcCore


class InstantOnboardingViewController: UIViewController, ProgressAlertHandler {

    private var dcContext: DcContext
    private let dcAccounts: DcAccounts
    weak var progressAlert: UIAlertController?
    var progressObserver: NSObjectProtocol?
    private var qrCodeReader: QrCodeReaderController?
    private var securityScopedResource: NSURL?
    private var backupProgressObserver: NSObjectProtocol?
    private lazy var canCancel: Bool = {
        // "cancel" removes selected unconfigured account, so there needs to be at least one other account
        return dcAccounts.getAll().count >= 2
    }()

    var contentView: InstantOnboardingView? { view as? InstantOnboardingView }

    private var providerHostURL: URL
    private var qrCodeData: String?

    // TODO: Maybe use DI instead of lazily computed property?
    private lazy var mediaPicker: MediaPicker = {
        let mediaPicker = MediaPicker(dcContext: dcContext, navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()
    
    /// Creates Instant Onboarding-Screen. You can inject some QR-Code-Data to change the chatmail provider
    /// If `qrCodeData` is `nil`, the default server is used, currently it's `nine.testrun.org`
    /// - Parameters:
    ///   - dcAccounts: Account to be used
    ///   - qrCodeData: DeltaChat QR Code Data
    init(dcAccounts: DcAccounts, qrCodeData: String? = nil) {
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()

        if let qrCodeData {
            let parsedQrCode = dcContext.checkQR(qrCode: qrCodeData)
            if parsedQrCode.state == DC_QR_LOGIN || parsedQrCode.state == DC_QR_ACCOUNT,
               let host = parsedQrCode.text1,
               let url = URL(string: "https://\(host)") {
                self.providerHostURL = url
                self.qrCodeData = qrCodeData
            } else {
                self.providerHostURL = URL(string: "https://nine.testrun.org")!
                self.qrCodeData = nil
            }
        } else {
            self.providerHostURL = URL(string: "https://nine.testrun.org")!
            self.qrCodeData = nil
        }

        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true
        title = String.localized("pref_profile_info_headline")

        NotificationCenter.default.addObserver(self, selector: #selector(InstantOnboardingViewController.keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(InstantOnboardingViewController.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        super.loadView()

        let contentView = InstantOnboardingView(avatarImage: dcContext.getSelfAvatarImage())
        contentView.agreeButton.addTarget(self, action: #selector(InstantOnboardingViewController.acceptAndCreateButtonPressed), for: .touchUpInside)
        contentView.imageButton.addTarget(self, action: #selector(InstantOnboardingViewController.onAvatarTapped), for: .touchUpInside)
        contentView.privacyButton.addTarget(self, action: #selector(InstantOnboardingViewController.showPrivacy(_:)), for: .touchUpInside)
        contentView.otherOptionsButton.addTarget(self, action: #selector(InstantOnboardingViewController.showOtherOptions(_:)), for: .touchUpInside)
        contentView.scanQRCodeButton.addTarget(self, action: #selector(InstantOnboardingViewController.scanQRCode(_:)), for: .touchUpInside)


        NotificationCenter.default.addObserver(
            self,
            selector: #selector(InstantOnboardingViewController.textDidChangeNotification(notification:)),
            name: UITextField.textDidChangeNotification,
            object: contentView.nameTextField
        )

        self.view = contentView
    }

    override func viewDidDisappear(_ animated: Bool) {
        if let progressObserver {
            NotificationCenter.default.removeObserver(progressObserver)
            self.progressObserver = nil
        }

        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: contentView?.nameTextField)
    }

    // MARK: - Notifications

    @objc func textDidChangeNotification(notification: Notification) {
        guard let textField = notification.object as? UITextField,
              let text = textField.text else { return }

        let buttonShouldBeEnabled = (text.isEmpty == false)
        contentView?.agreeButton.isEnabled = buttonShouldBeEnabled

        if buttonShouldBeEnabled {
            contentView?.agreeButton.backgroundColor = .systemBlue
        } else {
            contentView?.agreeButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.6)
        }
    }

    // MARK: - actions
    private func galleryButtonPressed(_ action: UIAlertAction) {
        mediaPicker.showPhotoGallery()
    }

    private func cameraButtonPressed(_ action: UIAlertAction) {
        mediaPicker.showCamera(allowCropping: true, supportedMediaTypes: .photo)
    }

    private func deleteProfileIconPressed(_ action: UIAlertAction) {
        dcContext.selfavatar = nil
        contentView?.imageButton.setImage(UIImage(named: "person.crop.circle"), for: .normal)
    }

    @objc private func showPrivacy(_ sender: UIButton) {
        let url = providerHostURL.appendingPathComponent("/privacy.html")

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    @objc private func showOtherOptions(_ sender: UIButton) {

        guard let url = URL(string: "https://delta.chat/en/chatmail") else { return }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    @objc private func scanQRCode(_ sender: UIButton) {
        let qrReader = QrCodeReaderController(title: String.localized("multidevice_receiver_title"),
                    addHints: "➊ " + String.localized("multidevice_same_network_hint") + "\n\n"
                        +     "➋ " + String.localized("multidevice_open_settings_on_other_device") + "\n\n"
                        +     String.localized("multidevice_experimental_hint"),
                    showTroubleshooting: true)
        qrReader.delegate = self

        navigationController?.pushViewController(qrReader, animated: true)

        self.qrCodeReader = qrReader
    }

    @objc
    private func onAvatarTapped() {
        let alert = UIAlertController(title: String.localized("pref_profile_photo"), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(PhotoPickerAlertAction(title: String.localized("camera"), style: .default, handler: cameraButtonPressed(_:)))
        alert.addAction(PhotoPickerAlertAction(title: String.localized("gallery"), style: .default, handler: galleryButtonPressed(_:)))
        if dcContext.getSelfAvatarImage() != nil {
            alert.addAction(UIAlertAction(title: String.localized("delete"), style: .destructive, handler: deleteProfileIconPressed(_:)))
        }
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))

        self.present(alert, animated: true, completion: nil)
    }

    // MARK: - Notifications
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        var keyboardFrame: CGRect = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
        keyboardFrame = view.convert(keyboardFrame, from: nil)

        var contentInset = contentView.contentScrollView.contentInset
        contentInset.bottom = keyboardFrame.size.height + 20

        contentView.contentScrollView.contentInset = contentInset
        contentView.spacer.isHidden = true
        contentView.bottomSpacer.isHidden = false
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        contentView.spacer.isHidden = false
        contentView.bottomSpacer.isHidden = true
        contentView.contentScrollView.contentInset = UIEdgeInsets.zero
    }

    // MARK: - action: configuration
    @objc private func acceptAndCreateButtonPressed() {
        addProgressAlertListener(dcAccounts: self.dcAccounts, progressName: eventConfigureProgress, onSuccess: self.handleCreateSuccess)
        showProgressAlert(title: String.localized("add_account"), dcContext: self.dcContext)

        DispatchQueue.global().async { [weak self] in
            guard let self else { return }

            let qrCodeData = self.qrCodeData ?? "dcaccount:https://nine.testrun.org/new"
            let success = self.dcContext.setConfigFromQR(qrCode: qrCodeData)
            DispatchQueue.main.async {
                if success {
                    self.dcAccounts.stopIo()
                    self.dcContext.configure()
                } else {
                    self.updateProgressAlert(error: self.dcContext.lastErrorString, completion: nil)
                }
            }
        }

    }

    private func handleCreateSuccess() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        if !UserDefaults.standard.bool(forKey: "notifications_disabled") {
            appDelegate.registerForNotifications()
        }

        appDelegate.reloadDcContext()
    }
}

// MARK: - MediaPickerDelegate
extension InstantOnboardingViewController: MediaPickerDelegate {
    func onImageSelected(image: UIImage) {
        AvatarHelper.saveSelfAvatarImage(dcContext: dcContext, image: image)
        contentView?.imageButton.setImage(image, for: .normal)
    }
}

// MARK: - QrCodeReaderDelegate
extension InstantOnboardingViewController: QrCodeReaderDelegate {
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
                // if an injected qrCodeData exists, the InstantOnboardingViewController was only opened to handle that
                // cancelling the action should also dismiss the whole controller
                if self.qrCodeData != nil {
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
                if self.qrCodeData != nil {
                    // if an injected qrCodeData exists, the WelcomeViewController was only opened to handle that
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
                                                 completion: self.qrCodeData != nil ? self.cancelAccountCreation : nil)
                    }
                }
            }
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

    private func handleLoginSuccess() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        if !UserDefaults.standard.bool(forKey: "notifications_disabled") {
            appDelegate.registerForNotifications()
        }

        let profileInfoController = ProfileInfoViewController(context: self.dcContext)
        profileInfoController.onClose = {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.reloadDcContext()
            }
        }

        navigationController?.setViewControllers([profileInfoController], animated: true)
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

    private func removeBackupProgressObserver() {
        if let backupProgressObserver {
            NotificationCenter.default.removeObserver(backupProgressObserver)
            self.backupProgressObserver = nil
        }
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
}

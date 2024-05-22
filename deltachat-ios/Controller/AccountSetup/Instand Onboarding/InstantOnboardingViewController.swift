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

    deinit {
        if let progressObserver {
            NotificationCenter.default.removeObserver(progressObserver)
        }

        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: contentView?.nameTextField)
    }

    override func loadView() {
        super.loadView()
        let customProvider: String?
        if qrCodeData != nil {
            customProvider = providerHostURL.host
        } else {
            customProvider = nil
        }
        let contentView = InstantOnboardingView(avatarImage: dcContext.getSelfAvatarImage(), name: dcContext.displayname, customProvider: customProvider)
        contentView.agreeButton.addTarget(self, action: #selector(InstantOnboardingViewController.acceptAndCreateButtonPressed), for: .touchUpInside)
        contentView.imageButton.addTarget(self, action: #selector(InstantOnboardingViewController.onAvatarTapped), for: .touchUpInside)
        contentView.privacyButton.addTarget(self, action: #selector(InstantOnboardingViewController.showPrivacy(_:)), for: .touchUpInside)
        contentView.otherOptionsButton.addTarget(self, action: #selector(InstantOnboardingViewController.showOtherOptions(_:)), for: .touchUpInside)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(InstantOnboardingViewController.textDidChangeNotification(notification:)),
            name: UITextField.textDidChangeNotification,
            object: contentView.nameTextField
        )

        self.view = contentView
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        dcContext.displayname = contentView?.nameTextField.text
    }

    // MARK: - Notifications

    @objc func textDidChangeNotification(notification: Notification) {
        guard let textField = notification.object as? UITextField,
              let text = textField.text else { return }

        contentView?.validateTextfield(text: text)
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

    @objc private func showOtherOptions(_ sender: UIButton) {
        let alertController = UIAlertController(title: String.localized("instant_onboarding_show_more_instances"), message: nil, preferredStyle: .safeActionSheet)
        let otherServersAction = UIAlertAction(title: String.localized("instant_onboarding_other_server"), style: .default) { _ in
            guard let url = URL(string: "https://delta.chat/en/chatmail") else { return }

            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }

        let manualAccountSetup = UIAlertAction(title: String.localized("manual_account_setup_option"), style: .default) { _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                let accountSetupController = AccountSetupController(dcAccounts: self.dcAccounts, editView: false)
                accountSetupController.onLoginSuccess = {
                    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                        appDelegate.reloadDcContext()
                    }
                }
                self.navigationController?.pushViewController(accountSetupController, animated: true)
            }
        }

        let scanQRCode = UIAlertAction(title: String.localized("scan_invitation_code"), style: .default) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                let qrReader = QrCodeReaderController(title: String.localized("scan_invitation_code"))
                qrReader.delegate = self

                navigationController?.pushViewController(qrReader, animated: true)

                self.qrCodeReader = qrReader
            }
        }

        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .cancel)

        alertController.addAction(otherServersAction)
        alertController.addAction(manualAccountSetup)
        alertController.addAction(scanQRCode)
        alertController.addAction(cancelAction)

        present(alertController, animated: true)
    }

    // MARK: - Notifications
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              var keyboardFrame: CGRect = userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect,
              let contentView = contentView else { return }

        keyboardFrame = view.convert(keyboardFrame, from: nil)

        var contentInset = contentView.contentScrollView.contentInset
        contentInset.bottom = keyboardFrame.size.height + 20

        contentView.contentScrollView.contentInset = contentInset
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        contentView?.contentScrollView.contentInset = UIEdgeInsets.zero
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
        // update with new code
        let parsedQrCode = dcContext.checkQR(qrCode: code)
        if parsedQrCode.state == DC_QR_LOGIN || parsedQrCode.state == DC_QR_ACCOUNT,
           let host = parsedQrCode.text1,
           let url = URL(string: "https://\(host)") {
            self.providerHostURL = url
            self.qrCodeData = code

            contentView?.updateContent(with: host)
            dismissQRReader()
        } else {
            qrErrorAlert()
        }
    }

    private func qrErrorAlert() {
        let title = String.localized("qraccount_qr_code_cannot_be_used")
        let alert = UIAlertController(title: title, message: dcContext.lastErrorString, preferredStyle: .alert)
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

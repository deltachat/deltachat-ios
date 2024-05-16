import UIKit
import DcCore


class InstantOnboardingViewController: UIViewController, ProgressAlertHandler {

    private let dcContext: DcContext
    private let dcAccounts: DcAccounts
    weak var progressAlert: UIAlertController?
    var progressObserver: NSObjectProtocol?

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
        // TODO: Implement
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

extension InstantOnboardingViewController: MediaPickerDelegate {
    func onImageSelected(image: UIImage) {
        AvatarHelper.saveSelfAvatarImage(dcContext: dcContext, image: image)
        contentView?.imageButton.setImage(image, for: .normal)
    }
}

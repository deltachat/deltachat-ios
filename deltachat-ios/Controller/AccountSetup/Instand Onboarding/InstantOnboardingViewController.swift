import UIKit
import DcCore


class InstantOnboardingViewController: UIViewController, MediaPickerDelegate, ProgressAlertHandler {

    private let dcContext: DcContext
    private let dcAccounts: DcAccounts
    weak var progressAlert: UIAlertController?
    var progressObserver: NSObjectProtocol?

    var contentView: InstantOnboardingView { view as! InstantOnboardingView }

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(dcContext: dcContext, navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()

        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true

        title = String.localized("pref_profile_info_headline")
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        super.loadView()

        let contentView = InstantOnboardingView(frame: .zero)
        contentView.agreeButton.addTarget(self, action: #selector(InstantOnboardingViewController.acceptAndCreateButtonPressed), for: .touchUpInside)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(InstantOnboardingViewController.textDidChangeNotification(notification:)),
            name: UITextField.textDidChangeNotification,
            object: contentView.nameTextField
        )

        self.view = contentView
    }

    override func viewDidDisappear(_ animated: Bool) {
        if let observer = progressObserver {
            NotificationCenter.default.removeObserver(observer)
            progressObserver = nil
        }
    }

    // MARK: - Notifications

    @objc func textDidChangeNotification(notification: Notification) {
        guard let textField = notification.object as? UITextField,
              let text = textField.text else { return }

        let buttonShouldBeEnabled = (text.isEmpty == false)
        contentView.agreeButton.isEnabled = buttonShouldBeEnabled

        if buttonShouldBeEnabled {
            contentView.agreeButton.backgroundColor = .systemBlue
        } else {
            contentView.agreeButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.6)
        }

    }

    // MARK: - actions
    private func galleryButtonPressed(_ action: UIAlertAction) {
        mediaPicker?.showPhotoGallery()
    }

    private func cameraButtonPressed(_ action: UIAlertAction) {
        mediaPicker?.showCamera(allowCropping: true, supportedMediaTypes: .photo)
    }

    private func deleteProfileIconPressed(_ action: UIAlertAction) {
        dcContext.selfavatar = nil
    }

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

    func onImageSelected(image: UIImage) {
        AvatarHelper.saveSelfAvatarImage(dcContext: dcContext, image: image)
    }

    // MARK: - action: configuration
    @objc private func acceptAndCreateButtonPressed() {
        addProgressAlertListener(dcAccounts: self.dcAccounts, progressName: eventConfigureProgress, onSuccess: self.handleCreateSuccess)
        showProgressAlert(title: String.localized("add_account"), dcContext: self.dcContext)

        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let success = self.dcContext.setConfigFromQR(qrCode: "dcaccount:https://nine.testrun.org/new") // TODO: this may be replaced by a scanned QR code or tapped invite-link
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

import UIKit
import DcCore

class InstantOnboardingViewController: UITableViewController, MediaPickerDelegate, ProgressAlertHandler {

    private struct SectionConfigs {
        let headerTitle: String?
        let footerTitle: String?
        let cells: [UITableViewCell]
    }

    private let dcContext: DcContext
    private let dcAccounts: DcAccounts
    weak var progressAlert: UIAlertController?
    var progressObserver: NSObjectProtocol?

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(dcContext: dcContext, navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    private lazy var avatarSelectionCell: AvatarSelectionCell = {
        return AvatarSelectionCell(image: dcContext.getSelfAvatarImage())
    }()

    private lazy var nameCell: TextFieldCell = {
        let cell = TextFieldCell(description: String.localized("pref_your_name"), placeholder: String.localized("pref_your_name"))
        cell.setText(text: dcContext.displayname)
        cell.textFieldDelegate = self
        cell.textField.returnKeyType = .default
        return cell
    }()

    private lazy var sections: [SectionConfigs] = {
        let nameSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: String.localized("set_name_and_avatar_explain"),
            cells: [nameCell, avatarSelectionCell]
        )
        return [nameSection]
    }()

    private lazy var acceptAndCreateButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            title: String.localized("instant_onboarding_create"),
            style: .done,
            target: self,
            action: #selector(acceptAndCreateButtonPressed))
        return button
    }()

    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()
        super.init(style: .grouped)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = acceptAndCreateButton
        title = String.localized("pref_profile_info_headline")
        avatarSelectionCell.onAvatarTapped = { [weak self] in
            self?.onAvatarTapped()
        }
        tableView.rowHeight = UITableView.automaticDimension
    }

    override func viewWillDisappear(_ animated: Bool) {
        dcContext.displayname = nameCell.getText()
    }

    override func viewDidDisappear(_ animated: Bool) {
        if let observer = progressObserver {
            NotificationCenter.default.removeObserver(observer)
            progressObserver = nil
        }
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return sections[indexPath.section].cells[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerTitle
    }

    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
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
        updateAvatarCell()
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
        updateAvatarCell()
    }

    private func updateAvatarCell() {
        self.avatarSelectionCell.setAvatar(image: dcContext.getSelfAvatarImage())
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


extension InstantOnboardingViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

import UIKit
import DcCore

class ProfileSettingsViewController: UITableViewController, MediaPickerDelegate {
    private let dcContext: DcContext
    private let dcAccounts: DcAccounts

    private let section1 = 0
    private let section1Name = 0
    private let section1Avatar = 1
    private let section1Status = 2
    private let section1RowCount = 3

    private let section2 = 1
    private let section2AccountSettings = 0
    private let section2RowCount = 1

    private let sectionCount = 2

    private let tagAccountSettingsCell = 1

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    private lazy var statusCell: MultilineTextFieldCell = {
        let cell = MultilineTextFieldCell(description: String.localized("pref_default_status_label"),
                                          multilineText: dcContext.selfstatus,
                                          placeholder: String.localized("pref_default_status_label"))
        return cell
    }()

    private lazy var accountSettingsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("pref_password_and_account_settings")
        cell.accessoryType = .disclosureIndicator
        cell.tag = tagAccountSettingsCell
        return cell
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
        title = String.localized("pref_profile_info_headline")
        avatarSelectionCell.onAvatarTapped = { [weak self] in
            self?.onAvatarTapped()
        }
        tableView.rowHeight = UITableView.automaticDimension
    }

    override func viewWillDisappear(_ animated: Bool) {
        dcContext.selfstatus = statusCell.getText()
        dcContext.displayname = nameCell.getText()
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sectionCount
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == section1 {
            return section1RowCount
        } else {
            return section2RowCount
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == section1 {
            switch indexPath.row {
            case section1Avatar:
                return avatarSelectionCell
            case section1Name:
                return nameCell
            case section1Status:
                return statusCell
            default:
               return UITableViewCell()
            }
        } else {
            return accountSettingsCell
        }
    }

    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == section1 {
            return String.localized("pref_who_can_see_profile_explain")
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        if cell.tag == tagAccountSettingsCell {
            tableView.deselectRow(at: indexPath, animated: false)
            guard let nc = navigationController else { return }
            let accountSetupVC = AccountSetupController(dcAccounts: dcAccounts, editView: true)
            nc.pushViewController(accountSetupVC, animated: true)
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

}


extension ProfileSettingsViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

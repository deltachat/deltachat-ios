import UIKit
import DcCore

class EditSettingsController: UITableViewController, MediaPickerDelegate {

    private let dcContext: DcContext
    weak var coordinator: EditSettingsCoordinator?
    private var displayNameBackup: String?
    private var statusCellBackup: String?

    private let groupBadgeSize: CGFloat = 72

    private let section1 = 0
    private let section1Avatar = 0
    private let section1Name = 1
    private let section1Status = 2
    private let section1RowCount = 3

    private let section2 = 1
    private let section2AccountSettings = 0
    private let section2RowCount = 1

    private let sectionCount = 2

    private let tagAccountSettingsCell = 1

    private var childCoordinators: Coordinator?

    private lazy var statusCell: MultilineTextFieldCell = {
        let cell = MultilineTextFieldCell(description: String.localized("pref_default_status_label"),
                                          multilineText: dcContext.selfstatus,
                                          placeholder: String.localized("pref_default_status_label"))
        return cell
    }()

    private lazy var accountSettingsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("pref_password_and_account_settings")
        cell.accessoryType = .disclosureIndicator
        cell.tag = tagAccountSettingsCell
        return cell
    }()


    private lazy var avatarSelectionCell: AvatarSelectionCell = {
        return createPictureAndNameCell()
    }()

    private lazy var nameCell: TextFieldCell = {
        let cell = TextFieldCell(description: String.localized("pref_your_name"), placeholder: String.localized("pref_your_name"))
        cell.setText(text: dcContext.displayname)
        return cell
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(style: .grouped)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("pref_profile_info_headline")
        avatarSelectionCell.onAvatarTapped = onAvatarTapped
    }

    override func viewWillDisappear(_ animated: Bool) {
        dcContext.selfstatus = statusCell.getText()
        dcContext.displayname = nameCell.getText()
        dcContext.configure()
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

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == section1 {
            switch indexPath.row {
            case section1Avatar:
                return AvatarSelectionCell.cellSize
            case section1Status:
                return MultilineTextFieldCell.cellHeight
            default:
                 return Constants.defaultCellHeight
            }
        } else {
            return Constants.defaultCellHeight
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
            tableView.deselectRow(at: indexPath, animated: true)
            guard let nc = navigationController else { return }
            let accountSetupVC = AccountSetupController(dcContext: dcContext, editView: true)
            let coordinator = AccountSetupCoordinator(dcContext: dcContext, navigationController: nc)
            self.childCoordinators = coordinator
            accountSetupVC.coordinator = coordinator
            nc.pushViewController(accountSetupVC, animated: true)
        }
    }

    private func galleryButtonPressed(_ action: UIAlertAction) {
        coordinator?.showPhotoPicker(delegate: self)
    }

    private func cameraButtonPressed(_ action: UIAlertAction) {
        coordinator?.showCamera(delegate: self)
    }

    private func deleteProfileIconPressed(_ action: UIAlertAction) {
        dcContext.selfavatar = nil
        updateAvatarAndNameCell()
    }

    private func onAvatarTapped() {
        let alert = UIAlertController(title: String.localized("pref_profile_photo"), message: nil, preferredStyle: .safeActionSheet)
        let photoAction = PhotoPickerAlertAction(title: String.localized("gallery"), style: .default, handler: galleryButtonPressed(_:))
        let videoAction = PhotoPickerAlertAction(title: String.localized("camera"), style: .default, handler: cameraButtonPressed(_:))
        let deleteAction = UIAlertAction(title: String.localized("delete"), style: .destructive, handler: deleteProfileIconPressed(_:))

        alert.addAction(photoAction)
        alert.addAction(videoAction)
        if dcContext.getSelfAvatarImage() != nil {
            alert.addAction(deleteAction)
        }
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))

        self.present(alert, animated: true, completion: nil)
    }

    func onImageSelected(image: UIImage) {
        AvatarHelper.saveSelfAvatarImage(dcContext: dcContext, image: image)
        updateAvatarAndNameCell()
    }

    private func updateAvatarAndNameCell() {
        self.avatarSelectionCell = createPictureAndNameCell()
        self.avatarSelectionCell.onAvatarTapped = onAvatarTapped

        self.tableView.beginUpdates()
        let indexPath = IndexPath(row: section1Avatar, section: section1)
        self.tableView.reloadRows(at: [indexPath], with: UITableView.RowAnimation.none)
        self.tableView.endUpdates()
    }

    private func createPictureAndNameCell() -> AvatarSelectionCell {
        let cell = AvatarSelectionCell(context: dcContext)
        return cell
    }

}

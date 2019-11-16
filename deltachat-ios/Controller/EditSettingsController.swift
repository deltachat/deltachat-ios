import UIKit

class EditSettingsController: UITableViewController, MediaPickerDelegate {

    private let dcContext: DcContext
    weak var coordinator: EditSettingsCoordinator?
    private var displayNameBackup: String?
    private var statusCellBackup: String?

    private let groupBadgeSize: CGFloat = 72

    private let section1 = 0
    private let section1PictureAndName = 0
    private let section1Status = 1
    private let section1RowCount = 2

    private let section2 = 1
    private let section2AccountSettings = 0
    private let section2RowCount = 1

    private let sectionCount = 2

    private let tagAccountSettingsCell = 1

    private var childCoordinators: Coordinator?

    private lazy var defaultImage: UIImage = {
        if let image = UIImage(named: "camera") {
            return image.invert()
        }
        return UIImage()
    }()

    private lazy var statusCell: TextFieldCell = {
        let cell = TextFieldCell(description: String.localized("pref_default_status_label"), placeholder: String.localized("pref_default_status_label"))
        cell.setText(text: DcConfig.selfstatus ?? nil)
        return cell
    }()

    private lazy var accountSettingsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("pref_password_and_account_settings")
        cell.accessoryType = .disclosureIndicator
        cell.tag = tagAccountSettingsCell
        return cell
    }()


    private lazy var pictureAndNameCell: AvatarEditTextCell = {
        let contact = DcContact(id: Int(DC_CONTACT_ID_SELF))
        let cell = AvatarEditTextCell(context: dcContext, defaultImage: defaultImage)
        cell.inputField.text = contact.displayName
        cell.selectionStyle = .none
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

        tableView.register(AvatarEditTextCell.self, forCellReuseIdentifier: "pictureAndNameCell")
        tableView.register(ContactCell.self, forCellReuseIdentifier: "contactCell")
        pictureAndNameCell.onAvatarTapped = onAvatarTapped
    }

    override func viewWillDisappear(_ animated: Bool) {
        DcConfig.selfstatus = statusCell.getText()
        DcConfig.displayname = pictureAndNameCell.getText()
        dc_configure(mailboxPointer)
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
            case section1PictureAndName:
                return pictureAndNameCell
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
        if indexPath.section == section1 && indexPath.row == section1PictureAndName {
            return AvatarEditTextCell.cellSize
        } else {
            return 48
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


      private func photoButtonPressed(_ action: UIAlertAction) {
        coordinator?.showPhotoPicker(delegate: self)
      }

      private func videoButtonPressed(_ action: UIAlertAction) {
        ///TODO implement me!
      }

    private func onAvatarTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                 let photoAction = PhotoPickerAlertAction(title: String.localized("gallery"), style: .default, handler: photoButtonPressed(_:))
                 let videoAction = PhotoPickerAlertAction(title: String.localized("camera"), style: .default, handler: videoButtonPressed(_:))

                 alert.addAction(photoAction)
                 alert.addAction(videoAction)
                 alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))

        self.present(alert, animated: true, completion: nil)
    }

    func onMediaSelected(url: NSURL) {
        logger.info("onMediaSelected: \(url)")
        DcConfig.selfavatar = "\(url)"
        pictureAndNameCell.setSelfAvatar(context: dcContext, with: defaultImage)
    }

    func onDismiss() { }

}

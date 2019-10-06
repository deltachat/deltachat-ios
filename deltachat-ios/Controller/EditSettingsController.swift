import UIKit

class EditSettingsController: UITableViewController {

    private let dcContext: DcContext
    private var displayNameBackup: String?
    private var statusCellBackup: String?

    private let section1 = 0
    private let section1Name = 0
    private let section1Status = 1
    private let section1RowCount = 2

    private let section2 = 1
    private let section2AccountSettings = 0
    private let section2RowCount = 1

    private let sectionCount = 2

    private lazy var displayNameCell: TextFieldCell = {
        let cell = TextFieldCell(description: String.localized("pref_your_name"), placeholder: String.localized("pref_your_name"))
        cell.setText(text: DcConfig.displayname ?? nil)
        return cell
    }()

    private lazy var statusCell: TextFieldCell = {
        let cell = TextFieldCell(description: String.localized("pref_default_status_label"), placeholder: String.localized("pref_default_status_label"))
        cell.setText(text: DcConfig.selfstatus ?? nil)
        return cell
    }()

    lazy var accountSettingsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("pref_password_and_account_settings")
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "accountSettingsCell"
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
    }

    override func viewWillAppear(_ animated: Bool) {
        displayNameBackup = DcConfig.displayname
        statusCellBackup = DcConfig.selfstatus
    }

    override func viewWillDisappear(_ animated: Bool) {
        if displayNameBackup != displayNameCell.getText() || statusCellBackup != displayNameCell.getText() {
            DcConfig.selfstatus = statusCell.getText()
            DcConfig.displayname = displayNameCell.getText()
            dc_configure(mailboxPointer)
        }
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
            if indexPath.row == section1Name {
                return displayNameCell
            } else {
                return statusCell
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
        if cell.accessibilityIdentifier == "accountSettingsCell" {
            tableView.deselectRow(at: indexPath, animated: true)
            guard let nc = navigationController else { return }
            let accountSetupVC = AccountSetupController(dcContext: dcContext, editView: true)
            let coordinator = AccountSetupCoordinator(dcContext: dcContext, navigationController: nc)
            accountSetupVC.coordinator = coordinator
            nc.pushViewController(accountSetupVC, animated: true)
        }
    }
}

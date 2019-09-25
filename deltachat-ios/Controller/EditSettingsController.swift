import UIKit

class EditSettingsController: UITableViewController {

    private let dcContext: DcContext
    private var displayNameBackup: String?
    private var statusCellBackup: String?

    private let section1 = 0
    private let section1Name = 0
    private let section1Status = 1
    private let section1RowCount = 2
    private let sectionCount = 1

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

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(style: .grouped)
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
        return section1RowCount
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == section1 && indexPath.row == section1Name {
            return displayNameCell
        }
        return statusCell
    }

    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == section1 {
            return String.localized("pref_who_can_see_profile_explain")
        } else {
            return nil
        }
    }
}

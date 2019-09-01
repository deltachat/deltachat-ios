import UIKit

class EditSettingsController: UITableViewController {

    private var displayNameBackup: String?
    private var statusCellBackup: String?

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

    init() {
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
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        if section == 0 {
            return displayNameCell
        } else {
            return statusCell
        }
    }

    func activateField(option: SettingsEditOption) {
        switch option {
        case .DISPLAYNAME:
            displayNameCell.textField.becomeFirstResponder()
        case .STATUS:
            statusCell.textField.becomeFirstResponder()
        }
    }
}

import UIKit

class EditSettingsController: UITableViewController {

    private var displayNameBackup: String?
    private var statusCellBackup: String?

    private lazy var displayNameCell: TextFieldCell = {
        let cell = TextFieldCell(description: "Display Name", placeholder: "Display Name")
        cell.setText(text: DCConfig.displayname ?? nil)
        return cell
    }()

    private lazy var statusCell: TextFieldCell = {
        let cell = TextFieldCell(description: "Status", placeholder: "Your Status")
        cell.setText(text: DCConfig.selfstatus ?? nil)
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
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func viewWillAppear(_ animated: Bool) {
        displayNameBackup = DCConfig.displayname
        statusCellBackup = DCConfig.selfstatus
    }

    override func viewWillDisappear(_ animated: Bool) {
        if displayNameBackup != displayNameCell.getText() || statusCellBackup != displayNameCell.getText() {
            DCConfig.selfstatus = statusCell.getText()
            DCConfig.displayname = displayNameCell.getText()	
            dc_configure(mailboxPointer)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
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

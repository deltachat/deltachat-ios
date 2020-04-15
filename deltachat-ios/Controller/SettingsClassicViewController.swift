import UIKit
import DcCore
class SettingsClassicViewController: UITableViewController {

    var dcContext: DcContext

    var options: [Int]

    var staticCells: [UITableViewCell] {
        return options.map({
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = SettingsClassicViewController.getValString(val: $0)
            cell.selectionStyle = .none
            return cell
        })
    }

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        self.options = [Int(DC_SHOW_EMAILS_OFF), Int(DC_SHOW_EMAILS_ACCEPTED_CONTACTS), Int(DC_SHOW_EMAILS_ALL)]
        super.init(style: .grouped)
        self.title = String.localized("pref_show_emails")
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    static public func getValString(val: Int) -> String {
        switch Int32(val) {
        case DC_SHOW_EMAILS_OFF:
            return String.localized("pref_show_emails_no")
        case DC_SHOW_EMAILS_ACCEPTED_CONTACTS:
            return String.localized("pref_show_emails_accepted_contacts")
        case DC_SHOW_EMAILS_ALL:
            return String.localized("pref_show_emails_all")
        default:
            return "Err"
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let oldSelectedCell = tableView.cellForRow(at: IndexPath.init(row: dcContext.showEmails, section: 0))
        oldSelectedCell?.accessoryType = .none

        let newSelectedCell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row, section: 0))
        newSelectedCell?.accessoryType = .checkmark

        dcContext.showEmails = indexPath.row
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = staticCells[indexPath.row]
        if options[indexPath.row] == dcContext.showEmails {
            cell.accessoryType = .checkmark
        }
        return cell
    }
}

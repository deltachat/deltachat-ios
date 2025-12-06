import UIKit
import DcCore

protocol SecuritySettingsDelegate: AnyObject {
    func onSecuritySettingsChanged(newValue: String)
}

class SecuritySettingsViewController: UITableViewController {

    private let options: [String] = ["automatic", "ssl", "starttls", "plain"]
    private var selectedIndex: Int
    weak var delegate: SecuritySettingsDelegate?

    private var staticCells: [UITableViewCell] {
        return options.map {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = SecuritySettingsViewController.valueToName(value: $0)
            return cell
        }
    }

    init(initValue: String, title: String) {
        selectedIndex = options.firstIndex(of: initValue) ?? 0
        super.init(style: .insetGrouped)
        self.title = title
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = staticCells[indexPath.row]
        if selectedIndex == indexPath.row {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true) // animated as no other elements pop up
        if let cell = tableView.cellForRow(at: IndexPath(item: selectedIndex, section: 0)) {
            cell.accessoryType = .none
        }
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.accessoryType = .checkmark
        }
        selectedIndex = indexPath.row
        delegate?.onSecuritySettingsChanged(newValue: options[selectedIndex])
    }

    static func valueToName(value: String) -> String {
        switch value {
        case "automatic":
            return String.localized("automatic")
        case "ssl":
            return "SSL/TLS"
        case "starttls":
            return "StartTLS"
        case "plain":
            return String.localized("off")
        default:
            return value
        }
    }
}

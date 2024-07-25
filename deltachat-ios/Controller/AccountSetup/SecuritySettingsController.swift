import UIKit
import DcCore

protocol SecuritySettingsDelegate: AnyObject {
    func onSecuritySettingsChanged(type: SecurityType, newValue: Int)
}

class SecuritySettingsController: UITableViewController {

    private var options: [Int32] = [DC_SOCKET_AUTO, DC_SOCKET_SSL, DC_SOCKET_STARTTLS, DC_SOCKET_PLAIN]

    private var selectedIndex: Int
    private var securityType: SecurityType
    weak var delegate: SecuritySettingsDelegate?

    private var okButton: UIBarButtonItem {
        let button =  UIBarButtonItem(title: String.localized("ok"), style: .done, target: self, action: #selector(okButtonPressed))
        return button
    }

    private var cancelButton: UIBarButtonItem {
        let button =  UIBarButtonItem(title: String.localized("cancel"), style: .plain, target: self, action: #selector(cancelButtonPressed))
        return button
    }

    private var staticCells: [UITableViewCell] {
        return options.map {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = SecurityConverter.getSocketName(value: $0)
            return cell
        }
    }

    init(initValue: Int, title: String, type: SecurityType) {
        self.securityType = type
        selectedIndex = options.firstIndex(of: Int32(initValue)) ?? 0
        super.init(style: .grouped)
        self.title = title
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = okButton
        navigationItem.leftBarButtonItem = cancelButton
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
        selectedIndex = indexPath.row // TODO: callback to AccountSetupController here
    }

    @objc func okButtonPressed() {
        delegate?.onSecuritySettingsChanged(type: securityType, newValue: Int(options[selectedIndex]))
        navigationController?.popViewController(animated: true)
    }

    @objc func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }
}

enum SecurityType {
     case IMAPSecurity
     case SMTPSecurity
}

class SecurityConverter {
    static func getSocketName(value: Int32) -> String {
        switch value {
        case DC_SOCKET_AUTO:
            return String.localized("automatic")
        case DC_SOCKET_SSL:
            return "SSL/TLS"
        case DC_SOCKET_STARTTLS:
            return "StartTLS"
        case DC_SOCKET_PLAIN:
            return String.localized("off")
        default:
            return "Undefined"
        }
    }
}

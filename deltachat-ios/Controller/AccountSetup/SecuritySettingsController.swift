import UIKit
import DcCore

class SecuritySettingsController: UITableViewController {

    private var options: [Int32] = [DC_SOCKET_AUTO, DC_SOCKET_SSL, DC_SOCKET_STARTTLS, DC_SOCKET_PLAIN]

    private var selectedIndex: Int

    private var securityType: SecurityType
    private let dcContext: DcContext

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

    init(dcContext: DcContext, title: String, type: SecurityType) {
        self.securityType = type
        self.dcContext = dcContext
        switch securityType {
        case .IMAPSecurity:
            selectedIndex = options.firstIndex(of: Int32(dcContext.getConfigInt("mail_security"))) ?? 0
        case .SMTPSecurity:
            selectedIndex = options.firstIndex(of: Int32(dcContext.getConfigInt("send_security"))) ?? 0
        }
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

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

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
    }

    @objc func okButtonPressed() {
        switch securityType {
        case .IMAPSecurity:
            dcContext.setConfigInt("mail_security", Int(options[selectedIndex]))
        case .SMTPSecurity:
            dcContext.setConfigInt("send_security", Int(options[selectedIndex]))
        }
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

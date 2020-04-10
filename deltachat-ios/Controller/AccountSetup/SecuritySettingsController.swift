import UIKit
import DcCore

class SecuritySettingsController: UITableViewController {

    private var options: [Int]

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
            cell.textLabel?.text = SecurityConverter.convertHexToString(type: self.securityType, hex: $0)
            cell.selectionStyle = .none
            return cell
        }
    }

    init(dcContext: DcContext, title: String, type: SecurityType) {
        self.securityType = type
        self.dcContext = dcContext
        switch securityType {
        case .IMAPSecurity:
            options = [0x00, 0x100, 0x200, 0x400]
            selectedIndex = options.index(of: dcContext.getImapSecurity()) ?? 0
        case .SMTPSecurity:
            options = [0x00, 0x10000, 0x20000, 0x40000]
            selectedIndex = options.index(of: dcContext.getSmtpSecurity()) ?? 0
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
        // uselect old
        if let cell = tableView.cellForRow(at: IndexPath(item: selectedIndex, section: 0)) {
            cell.accessoryType = .none
        }
        // select new
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.accessoryType = .checkmark
        }
        selectedIndex = indexPath.row
    }

    @objc func okButtonPressed() {
        switch securityType {
        case .IMAPSecurity:
            dcContext.setImapSecurity(imapFlags: options[selectedIndex])
        case .SMTPSecurity:
            dcContext.setSmtpSecurity(smptpFlags: options[selectedIndex])
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
    static func convertHexToString(type: SecurityType, hex value: Int) -> String {
        switch value {
        case 0x0:
            return String.localized("automatic")
        case 0x100:
            return "StartTLS"
        case 0x200:
            return "SSL/TLS"
        case 0x400:
            return String.localized("off")
        case 0x10000:
            return "StartTLS"
        case 0x20000:
            return "SSL/TLS"
        case 0x40000:
            return String.localized("off")
        default:
            return "Undefined"
        }
    }
}

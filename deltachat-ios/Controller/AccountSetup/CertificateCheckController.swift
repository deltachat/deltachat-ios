import UIKit
import DcCore

class CertificateCheckController: UITableViewController {

    var options = [Int(DC_CERTCK_AUTO),
                   Int(DC_CERTCK_STRICT),
                   Int(DC_CERTCK_ACCEPT_INVALID_CERTIFICATES)]

    var currentValue: Int
    var selectedIndex: Int?
    let dcContext: DcContext

    var okButton: UIBarButtonItem {
        let button =  UIBarButtonItem(title: String.localized("ok"), style: .done, target: self, action: #selector(okButtonPressed))
        return button
    }

    var cancelButton: UIBarButtonItem {
        let button =  UIBarButtonItem(title: String.localized("cancel"), style: .plain, target: self, action: #selector(cancelButtonPressed))
        return button
    }

    var staticCells: [UITableViewCell] {
        return options.map({
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text =  ValueConverter.convertHexToString(value: $0)
            return cell
        })
    }

    init(dcContext: DcContext, sectionTitle: String?) {
        self.dcContext = dcContext
        self.currentValue = dcContext.certificateChecks
        for (index, value) in options.enumerated() where currentValue == value {
            selectedIndex = index
        }
        super.init(style: .grouped)
        self.title = sectionTitle
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true) // animated as no other elements pop up
        if indexPath.section == 0 {
            let row = indexPath.row
            selectItem(at: row)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        let cell = staticCells[row]
        if row == selectedIndex || cell.textLabel?.text == "\(currentValue)" {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }

    private func selectItem(at index: Int? ) {
        // TODO: callback to AccountSetupController here
        if let oldIndex = selectedIndex {
            let cell = tableView.cellForRow(at: IndexPath.init(row: oldIndex, section: 0))
            cell?.accessoryType = .none
        }
        if let newIndex = index {
            let cell = tableView.cellForRow(at: IndexPath.init(row: newIndex, section: 0))
            cell?.accessoryType = .checkmark
            currentValue = options[newIndex]
        }
        selectedIndex = index
    }

    @objc private func okButtonPressed() {
        dcContext.certificateChecks = currentValue // TODO: setting here is too soon
        navigationController?.popViewController(animated: true)
    }

    @objc private func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

   class ValueConverter {
        static func convertHexToString(value: Int) -> String {
            switch value {
            case Int(DC_CERTCK_AUTO):
                return String.localized("automatic")
            case Int(DC_CERTCK_STRICT):
                return String.localized("strict")
            case Int(DC_CERTCK_ACCEPT_INVALID_CERTIFICATES):
                return String.localized("accept_invalid_certificates")
            default:
                return "Undefined"
            }
        }
    }
}

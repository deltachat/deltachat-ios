import UIKit
import DcCore

protocol CertificateCheckDelegate: AnyObject {
    func onCertificateCheckChanged(newValue: Int)
}

class CertificateCheckController: UITableViewController {

    private let options = [Int(DC_CERTCK_AUTO), Int(DC_CERTCK_STRICT), Int(DC_CERTCK_ACCEPT_INVALID_CERTIFICATES)]
    private var currentValue: Int
    private var selectedIndex: Int?
    weak var delegate: CertificateCheckDelegate?

    var staticCells: [UITableViewCell] {
        return options.map({
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text =  ValueConverter.convertHexToString(value: $0)
            return cell
        })
    }

    init(initValue: Int, sectionTitle: String?) {
        self.currentValue = initValue
        for (index, value) in options.enumerated() where currentValue == value {
            selectedIndex = index
        }
        super.init(style: .insetGrouped)
        self.title = sectionTitle
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        delegate?.onCertificateCheckChanged(newValue: currentValue)
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

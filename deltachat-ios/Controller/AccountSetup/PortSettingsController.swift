import UIKit

class PortSettingsController: UITableViewController {

    var ports: [Int]

    private var sectionTitle: String?

    var onSave: ((String) -> Void)?

    var okButton: UIBarButtonItem {
        let button =  UIBarButtonItem(title: String.localized("ok"), style: .done, target: self, action: #selector(okButtonPressed))
        return button
    }

    var cancelButton: UIBarButtonItem {
        let button =  UIBarButtonItem(title: String.localized("cancel"), style: .plain, target: self, action: #selector(cancelButtonPressed))
        return button
    }

    var currentPort: Int
    var selectedIndex: Int?

    var staticCells: [UITableViewCell] {
        return ports.map({
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "\($0)"
            cell.selectionStyle = .none
            return cell
        })
    }

    lazy var customCell: TextFieldCell = {
        let cell = TextFieldCell(description: "", placeholder: "\(self.currentPort)")
        cell.selectionStyle = .none
        cell.textLabel?.text = nil
        cell.textField.keyboardType = .numberPad
        cell.onTextFieldChange = textFieldDidChange
        return cell
    }()

    init(sectionTitle: String?, ports: [Int], currentPort: Int?) {
        self.ports = ports
        self.sectionTitle = sectionTitle
        self.currentPort = currentPort ?? 0
        for (index, port) in ports.enumerated() where currentPort == port {
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

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return ports.count
        } else {
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let row = indexPath.row
            selectItem(at: row)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let section = indexPath.section
        let row = indexPath.row
        if section == 0 {
            let cell = staticCells[row]
            if row == selectedIndex || cell.textLabel?.text == "\(currentPort)" {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
            return cell
        } else {
            // section == 1
            return customCell
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return sectionTitle
        } else {
            return String.localized("custom_port")
        }
    }

    private func textFieldDidChange(_ textField: UITextField) {
        selectItem(at: nil)
        if let text = textField.text, let port = Int(text) {
            self.currentPort = port
        }
    }

    private func selectItem(at index: Int? ) {
        // unselect old cell
        // select new cell
        // update port
        if let oldIndex = selectedIndex {
            let cell = tableView.cellForRow(at: IndexPath.init(row: oldIndex, section: 0))
            cell?.accessoryType = .none
        }
        if let newIndex = index {
            // activate accesoryType on selected cell
            let cell = tableView.cellForRow(at: IndexPath.init(row: newIndex, section: 0))
            cell?.accessoryType = .checkmark
            currentPort = ports[newIndex]
            // update customCell
            customCell.textField.placeholder = "\(currentPort)"
            customCell.textField.resignFirstResponder()
            customCell.textField.text = nil // will display currentValue as placeholder
        }
        selectedIndex = index
    }

    @objc private func okButtonPressed() {
           onSave?("\(currentPort)")
           navigationController?.popViewController(animated: true)
       }

    @objc private func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

}

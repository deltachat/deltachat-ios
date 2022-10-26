import UIKit
import DcCore

class PredefinedVideoChatOptionCell: UITableViewCell {

    public var url: String

    init(label: String, url: String) {
        self.url = url
        super.init(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: label)
        self.textLabel?.text = label
        self.detailTextLabel?.text = url
        self.detailTextLabel?.textColor = .lightGray
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class SettingsVideoChatViewController: UITableViewController {

    private var dcContext: DcContext

    private let defaultOptions = [
        PredefinedVideoChatOptionCell(label: "Jitsi", url: "https://meet.jit.si/$ROOM"),
        PredefinedVideoChatOptionCell(label: "Systemli", url: "https://meet.systemli.org/$ROOM"),
        PredefinedVideoChatOptionCell(label: "Autistici", url: "https://vc.autistici.org/$ROOM"),
    ]

    private lazy var offCell: UITableViewCell = {
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: "off")
        cell.textLabel?.text = String.localized("off")
        return cell
    }()

    private lazy var customInstanceCell: TextFieldCell = {
        let cell = TextFieldCell.makeConfigCell(labelID: String.localized("custom"),
                                                placeholderID: String.localized("videochat_instance_placeholder"))
        cell.textField.autocapitalizationType = .none
        cell.textField.autocorrectionType = .no
        cell.textField.textContentType = .URL
        cell.textField.addTarget(self, action: #selector(setCustom), for: .editingDidBegin)
        cell.textField.addTarget(self, action: #selector(setCustom), for: .valueChanged)
        return cell
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(style: .grouped)
        self.updateSelected(selectedCustom: false)
        self.title = String.localized("videochat_instance")
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.defaultOptions.count + 2
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // selection changed, save value of custom field to ui config
        dcContext.setConfig("ui.custom_webrtc_instance", customInstanceCell.getText())
        
        var newInstance: String?
        var selectedCustom = false
        if indexPath.row == 0 {
            newInstance = ""
            self.view.endEditing(true)
        } else if indexPath.row <= self.defaultOptions.count {
            newInstance = self.defaultOptions[indexPath.row-1].url
            self.view.endEditing(true)
        } else {
            newInstance = customInstanceCell.getText()
            selectedCustom = true
        }
        
        dcContext.setConfig("webrtc_instance", newInstance)
        updateSelected(selectedCustom: selectedCustom)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // called when editing the value of the custom field or clicking on it
    @objc private func setCustom(_ textField: UITextField) {
        let newInstance = customInstanceCell.getText()
        dcContext.setConfig("ui.custom_webrtc_instance", newInstance)
        dcContext.setConfig("webrtc_instance", newInstance)
        // force select custom
        updateSelected(selectedCustom: true)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            return offCell
        } else if indexPath.row <= self.defaultOptions.count {
            return self.defaultOptions[indexPath.row-1]
        } else {
            return customInstanceCell
        }
    }

    var isCustom = false
    func updateSelected(selectedCustom: Bool) {
        self.isCustom = false
        var notDefault = true
        let currentUrl = dcContext.getConfig("webrtc_instance")
        // set selection
        for option in self.defaultOptions {
            if option.url == currentUrl {
                option.accessoryType = .checkmark
                notDefault = false
            } else {
                option.accessoryType = .none
            }
        }

        if notDefault {
            if (currentUrl?.isEmpty) != nil || selectedCustom {
                self.offCell.accessoryType = .none
                customInstanceCell.accessoryType = .checkmark
                customInstanceCell.textField.text = currentUrl
                self.isCustom = true
            } else {
                self.offCell.accessoryType = .checkmark
                customInstanceCell.accessoryType = .none
                customInstanceCell.textField.text = dcContext.getConfig("ui.custom_webrtc_instance")
            }
        } else {
            customInstanceCell.accessoryType = .none
            customInstanceCell.textField.text = dcContext.getConfig("ui.custom_webrtc_instance")
            self.offCell.accessoryType = .none
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return String.localized("videochat_instance_explain_2") + "\n\n" + String.localized("videochat_instance_example")
    }

    override func viewWillDisappear(_ animated: Bool) {
        let customTextField = customInstanceCell.getText()
        dcContext.setConfig("ui.custom_webrtc_instance", customTextField)
        if self.isCustom {
            dcContext.setConfig("webrtc_instance", customTextField)
        }
    }
}

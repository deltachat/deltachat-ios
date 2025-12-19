import UIKit
import DcCore

class AutodelOptionsViewController: UITableViewController {

    var dcContext: DcContext

    private struct Options {
        let value: Int
        let descr: String
    }

    private static let autodelDeviceOptions: [Options] = {
        return [
            Options(value: 0, descr: "never"),
            Options(value: 60 * 60, descr: "autodel_after_1_hour"),
            Options(value: 24 * 60 * 60, descr: "autodel_after_1_day"),
            Options(value: 7 * 24 * 60 * 60, descr: "autodel_after_1_week"),
            Options(value: 5 * 7 * 24 * 60 * 60, descr: "after_5_weeks"),
            Options(value: 365 * 24 * 60 * 60, descr: "autodel_after_1_year"),
        ]
    }()

    private static func autodelServerOptions(_ dcContext: DcContext) -> [Options] {
        if dcContext.isChatmail {
            return [
                Options(value: 0, descr: "automatic"),
                Options(value: 1, descr: "autodel_at_once"),
            ]
        } else {
            return [
                Options(value: 0, descr: "never"),
                Options(value: 1, descr: "autodel_at_once"),
                Options(value: 60 * 60, descr: "autodel_after_1_hour"),
                Options(value: 24 * 60 * 60, descr: "autodel_after_1_day"),
                Options(value: 7 * 24 * 60 * 60, descr: "autodel_after_1_week"),
                Options(value: 5 * 7 * 24 * 60 * 60, descr: "after_5_weeks"),
                Options(value: 365 * 24 * 60 * 60, descr: "autodel_after_1_year"),
            ]
        }
    }

    private lazy var autodelOptions: [Options] = {
        return fromServer ? AutodelOptionsViewController.autodelServerOptions(dcContext) : AutodelOptionsViewController.autodelDeviceOptions
    }()

    var fromServer: Bool
    var currVal: Int

    private var cancelButton: UIBarButtonItem {
        let button =  UIBarButtonItem(title: String.localized("cancel"), style: .plain, target: self, action: #selector(cancelButtonPressed))
        return button
    }

    private var okButton: UIBarButtonItem {
        let button =  UIBarButtonItem(title: String.localized("ok"), style: .done, target: self, action: #selector(okButtonPressed))
        return button
    }

    var staticCells: [UITableViewCell] {
        return autodelOptions.map({
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = String.localized($0.descr)
            cell.accessoryType = $0.value==currVal ? .checkmark : .none
            return cell
        })
    }

    init(dcContext: DcContext, fromServer: Bool) {
        self.dcContext = dcContext
        self.fromServer = fromServer
        self.currVal = dcContext.getConfigInt(fromServer ? "delete_server_after" :  "delete_device_after")
        super.init(style: .insetGrouped)
        self.title = String.localized(fromServer ? "autodel_server_title" : "autodel_device_title")
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = okButton
    }

    static public func getSummary(_ dcContext: DcContext, fromServer: Bool) -> String {
        let val = dcContext.getConfigInt(fromServer ? "delete_server_after" :  "delete_device_after")
        let options = fromServer ? AutodelOptionsViewController.autodelServerOptions(dcContext) : AutodelOptionsViewController.autodelDeviceOptions
        for option in options {
            if option.value == val {
                return String.localized(option.descr)
            }
        }
 
        return "After \(val) seconds"
    }

    func valToIndex(val: Int) -> Int {
        var index = 0
        for option in autodelOptions {
            if option.value == val {
                return index
            }
            index += 1
        }
        return 0 // default to "off"
    }

    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return autodelOptions.count
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        let oldSelectedCell = tableView.cellForRow(at: IndexPath.init(row: self.valToIndex(val: self.currVal), section: 0))
        let newSelectedCell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row, section: 0))
        let newVal = self.autodelOptions[indexPath.row].value

        if newVal != currVal && newVal != 0 {
            let delCount = dcContext.estimateDeletionCnt(fromServer: fromServer, timeout: newVal)
            let newDescr = String.localized(self.autodelOptions[indexPath.row].descr)
            let msg = String.localizedStringWithFormat(String.localized(fromServer ? "autodel_server_ask" : "autodel_device_ask"), delCount, newDescr)
            let alert = UIAlertController(
                title: String.localized(fromServer ? "autodel_server_title" : "autodel_device_title"),
                message: msg,
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("autodel_confirm"), style: .destructive, handler: { [weak self] _ in
                oldSelectedCell?.accessoryType = .none
                newSelectedCell?.accessoryType = .checkmark
                self?.currVal = newVal
                self?.tableView.reloadData() // needed to update footer
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
            present(alert, animated: true, completion: nil)
        } else {
            oldSelectedCell?.accessoryType = .none
            newSelectedCell?.accessoryType = .checkmark
            currVal = newVal
            self.tableView.reloadData() // needed to update footer
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return staticCells[indexPath.row]
    }

    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        if fromServer && currVal != 0 {
            return String.localized("autodel_server_enabled_hint")
        }
        return nil
    }

    // MARK: - actions

    @objc private func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func okButtonPressed() {
        dcContext.setConfigInt(fromServer ? "delete_server_after" :  "delete_device_after", currVal)
        navigationController?.popViewController(animated: true)
    }
}

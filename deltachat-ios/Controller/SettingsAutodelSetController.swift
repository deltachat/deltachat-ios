import UIKit

class SettingsAutodelSetController: UITableViewController {

    var dcContext: DcContext

    private struct Options {
        let value: Int
        let descr: String
    }

    private lazy var autodelDeviceOptions: [Options] = {
        return [
            Options(value: 0, descr: "off"),
            Options(value: 3600, descr: "autodel_after_1_hour"),
            Options(value: 86400, descr: "autodel_after_1_day"),
            Options(value: 604800, descr: "autodel_after_1_week"),
            Options(value: 2419200, descr: "autodel_after_4_weeks"),
        ]
    }()

    private lazy var autodelServerOptions: [Options] = {
        return [
            Options(value: 0, descr: "off"),
            Options(value: 1, descr: "autodel_at_once"),
            Options(value: 3600, descr: "autodel_after_1_hour"),
            Options(value: 86400, descr: "autodel_after_1_day"),
            Options(value: 604800, descr: "autodel_after_1_week"),
            Options(value: 2419200, descr: "autodel_after_4_weeks"),
        ]
    }()

    private lazy var autodelOptions: [Options] = {
        return fromServer ? autodelServerOptions : autodelDeviceOptions
    }()

    var fromServer: Bool
    var enteringVal: Int
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
            cell.selectionStyle = .none
            cell.accessoryType = $0.value==currVal ? .checkmark : .none
            return cell
        })
    }

    init(dcContext: DcContext, fromServer: Bool) {
        self.dcContext = dcContext
        self.fromServer = fromServer
        self.enteringVal = dcContext.getConfigInt(fromServer ? "delete_server_after" :  "delete_device_after")
        self.currVal = enteringVal
        super.init(style: .grouped)
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

    static public func getAutodelString(fromServer: Bool, val: Int) -> String {
        // TODO
        return "Err"
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

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return autodelOptions.count
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let oldSelectedCell = tableView.cellForRow(at: IndexPath.init(row: valToIndex(val: currVal), section: 0))
        oldSelectedCell?.accessoryType = .none

        let newSelectedCell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row, section: 0))
        newSelectedCell?.accessoryType = .checkmark

        currVal = autodelOptions[indexPath.row].value
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return staticCells[indexPath.row]
    }

    // MARK: - actions

    @objc private func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func okButtonPressed() {
        navigationController?.popViewController(animated: true)
    }
}

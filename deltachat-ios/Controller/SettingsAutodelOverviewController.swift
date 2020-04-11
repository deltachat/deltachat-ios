import UIKit

class SettingsAutodelOverviewController: UITableViewController {

    var dcContext: DcContext

    private struct SectionConfigs {
        let headerTitle: String?
        let footerTitle: String?
        let cells: [UITableViewCell]
    }

    private enum CellTags: Int {
        case autodelDevice = 0
        case autodelServer = 1
    }

    func autodelSummary() -> String {
        return String.localized("off")
    }

    private lazy var autodelDeviceCell: UITableViewCell = {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.tag = CellTags.autodelDevice.rawValue
        cell.textLabel?.text = String.localized("autodel_device_title")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = SettingsAutodelSetController.getSummary(dcContext, fromServer: false)
        return cell
    }()

    private lazy var autodelServerCell: UITableViewCell = {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.tag = CellTags.autodelServer.rawValue
        cell.textLabel?.text = String.localized("autodel_server_title")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = SettingsAutodelSetController.getSummary(dcContext, fromServer: true)
        return cell
    }()

    private lazy var sections: [SectionConfigs] = {
        let autodelSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: nil,
            cells: [autodelDeviceCell]
        )
        let autodelSection2 = SectionConfigs(
            headerTitle: nil,
            footerTitle: nil,
            cells: [autodelServerCell]
        )
        return [autodelSection, autodelSection2]
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(style: .grouped)
        self.title = String.localized("autodel_title")
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        autodelDeviceCell.detailTextLabel?.text = SettingsAutodelSetController.getSummary(dcContext, fromServer: false)
        autodelServerCell.detailTextLabel?.text = SettingsAutodelSetController.getSummary(dcContext, fromServer: true)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return sections[indexPath.section].cells[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerTitle
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath), let cellTag = CellTags(rawValue: cell.tag) else {
            safe_fatalError()
            return
        }
        tableView.deselectRow(at: indexPath, animated: false) // to achieve highlight effect

        switch cellTag {
        case .autodelDevice:
            let controller = SettingsAutodelSetController(dcContext: dcContext, fromServer: false)
            navigationController?.pushViewController(controller, animated: true)

        case .autodelServer:
            let controller = SettingsAutodelSetController(dcContext: dcContext, fromServer: true)
            navigationController?.pushViewController(controller, animated: true)
        }

    }
}

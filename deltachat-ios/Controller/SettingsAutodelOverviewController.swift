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
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.autodelDevice.rawValue
        cell.textLabel?.text = String.localized("autodel_device_title")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = autodelSummary()
        return cell
    }()

    private lazy var autodelServerCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.autodelServer.rawValue
        cell.textLabel?.text = String.localized("autodel_server_title")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = autodelSummary()
        return cell
    }()

    private lazy var sections: [SectionConfigs] = {
        let autodelSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: nil,
            cells: [autodelDeviceCell, autodelServerCell]
        )
        return [autodelSection]
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
    }
}

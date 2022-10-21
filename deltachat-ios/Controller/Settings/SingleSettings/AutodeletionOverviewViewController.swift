import UIKit
import DcCore

class AutodeletionOverviewViewController: UITableViewController {

    var dcContext: DcContext

    private struct SectionConfigs {
        let headerTitle: String?
        let cells: [UITableViewCell]
    }

    private enum CellTags: Int {
        case autodelDevice = 0
        case autodelServer = 1
    }

    private lazy var autodelDeviceCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.autodelDevice.rawValue
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.text = SetAutodeletionViewController.getSummary(dcContext, fromServer: false)
        return cell
    }()

    private lazy var autodelServerCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.autodelServer.rawValue
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.text = SetAutodeletionViewController.getSummary(dcContext, fromServer: true)
        return cell
    }()

    private lazy var sections: [SectionConfigs] = {
        let autodelSection = SectionConfigs(
            headerTitle: String.localized("autodel_device_title"),
            cells: [autodelDeviceCell]
        )
        let autodelSection2 = SectionConfigs(
            headerTitle: String.localized("autodel_server_title"),
            cells: [autodelServerCell]
        )
        return [autodelSection, autodelSection2]
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(style: .grouped)
        self.title = String.localized("delete_old_messages")
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
        tableView.reloadData() // needed to update footer
        autodelDeviceCell.textLabel?.text = SetAutodeletionViewController.getSummary(dcContext, fromServer: false)
        autodelServerCell.textLabel?.text = SetAutodeletionViewController.getSummary(dcContext, fromServer: true)
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
        guard let cellTag = CellTags(rawValue: section) else {
            safe_fatalError()
            return nil
        }
        if cellTag == .autodelServer && dcContext.getConfigInt("delete_server_after") != 0 {
            return String.localized("autodel_server_enabled_hint")
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath), let cellTag = CellTags(rawValue: cell.tag) else {
            safe_fatalError()
            return
        }
        tableView.deselectRow(at: indexPath, animated: false)

        switch cellTag {
        case .autodelDevice:
            let controller = SetAutodeletionViewController(dcContext: dcContext, fromServer: false)
            navigationController?.pushViewController(controller, animated: true)

        case .autodelServer:
            let controller = SetAutodeletionViewController(dcContext: dcContext, fromServer: true)
            navigationController?.pushViewController(controller, animated: true)
        }

    }
}

import UIKit
import DcCore
import Intents

internal final class ChatsAndMediaViewController: UITableViewController {

    private struct SectionConfigs {
        let headerTitle: String?
        let footerTitle: String?
        let cells: [UITableViewCell]
    }

    private enum CellTags: Int {
        case blockedContacts
        case receiptConfirmation
        case exportBackup
        case autodelDevice
        case autodelServer
        case mediaQuality
        case downloadOnDemand
    }

    private var dcContext: DcContext
    internal let dcAccounts: DcAccounts
    var progressAlertHandler: ProgressAlertHandler?

    // MARK: - cells

    private lazy var blockedContactsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.blockedContacts.rawValue
        cell.textLabel?.text = String.localized("pref_blocked_contacts")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    func autodelSummary() -> String {
        let delDeviceAfter = dcContext.getConfigInt("delete_device_after")
        let delServerAfter = dcContext.isChatmail ? 0 : dcContext.getConfigInt("delete_server_after")
        if delDeviceAfter==0 && delServerAfter==0 {
            return String.localized("never")
        } else {
            return String.localized("on")
        }
    }

    private lazy var autodelDeviceCell: UITableViewCell = {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.tag = CellTags.autodelDevice.rawValue
        cell.textLabel?.text = String.localized("autodel_device_title")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = AutodelOptionsViewController.getSummary(dcContext, fromServer: false)
        return cell
    }()

    private lazy var autodelServerCell: UITableViewCell = {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.tag = CellTags.autodelServer.rawValue
        cell.textLabel?.text = String.localized("autodel_server_title")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = AutodelOptionsViewController.getSummary(dcContext, fromServer: true)
        return cell
    }()

    private lazy var mediaQualityCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.mediaQuality.rawValue
        cell.textLabel?.text = String.localized("pref_outgoing_media_quality")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = MediaQualityViewController.getValString(val: dcContext.getConfigInt("media_quality"))
        return cell
    }()

    private lazy var downloadOnDemandCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.downloadOnDemand.rawValue
        cell.textLabel?.text = String.localized("auto_download_messages")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = DownloadOnDemandViewController.getValString(val: dcContext.getConfigInt("download_limit"))
        return cell
    }()

    private lazy var receiptConfirmationSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = dcContext.mdnsEnabled
        switchControl.addTarget(self, action: #selector(handleReceiptConfirmationToggle(_:)), for: .valueChanged)
        return switchControl
    }()

    private lazy var receiptConfirmationCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.receiptConfirmation.rawValue
        cell.textLabel?.text = String.localized("pref_read_receipts")
        cell.accessoryView = receiptConfirmationSwitch
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var exportBackupCell: ActionCell = {
        let cell = ActionCell()
        cell.tag = CellTags.exportBackup.rawValue
        cell.actionTitle = String.localized("export_backup_desktop")
        return cell
    }()

    private lazy var sections: [SectionConfigs] = {
        let preferencesSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: String.localized("pref_read_receipts_explain"),
            cells: [blockedContactsCell, mediaQualityCell, downloadOnDemandCell, receiptConfirmationCell]
        )
        let autoDelSection = SectionConfigs(
            headerTitle: String.localized("delete_old_messages"),
            footerTitle: nil,
            cells: dcContext.isChatmail ? [autodelDeviceCell] : [autodelDeviceCell, autodelServerCell]
        )
        let exportBackupSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: String.localized("pref_backup_explain"),
            cells: [exportBackupCell]
        )
        return [preferencesSection, autoDelSection, exportBackupSection]
    }()

    init(dcAccounts: DcAccounts) {
        self.dcContext = dcAccounts.getSelected()
        self.dcAccounts = dcAccounts
        super.init(style: .insetGrouped)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("pref_chats")
        tableView.rowHeight = UITableView.automaticDimension
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateCells()
    }

    // MARK: - UITableViewDelegate + UITableViewDatasource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return sections[indexPath.section].cells[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath), let cellTag = CellTags(rawValue: cell.tag) else {
            return assertionFailure()
        }
        tableView.deselectRow(at: indexPath, animated: false)

        switch cellTag {
        case .blockedContacts: showBlockedContacts()
        case .mediaQuality: showMediaQuality()
        case .downloadOnDemand: showDownloadOnDemand()
        case .receiptConfirmation: break

        case .autodelDevice:
            let controller = AutodelOptionsViewController(dcContext: dcContext, fromServer: false)
            navigationController?.pushViewController(controller, animated: true)

        case .autodelServer:
            let controller = AutodelOptionsViewController(dcContext: dcContext, fromServer: true)
            navigationController?.pushViewController(controller, animated: true)

        case .exportBackup:
            Utils.authenticateDeviceOwner(reason: String.localized("pref_backup_explain")) { [weak self] in
                self?.createBackup()
            }
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerTitle
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if sections[section].cells.last == autodelServerCell && dcContext.getConfigInt("delete_server_after") != 0 {
            return String.localized("autodel_server_enabled_hint")
        } else {
            return sections[section].footerTitle
        }
    }

    // MARK: - actions

    private func createBackup() {
        let alert = UIAlertController(title: String.localized("pref_backup_export_explain"), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("pref_backup_export_start_button"), style: .default, handler: { [weak self] _ in
            guard let self else { return }

            let progressHandler = ProgressAlertHandler(notification: Event.importExportProgress) { [weak self] in
                guard let self else { return }

                let alert = UIAlertController(
                    title: String.localized("backup_successful"),
                    message: String.localizedStringWithFormat(String.localized("backup_successful_explain_ios"), "\(String.localized("Files")) ➔ Delta Chat"),
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
            progressHandler.dataSource = self

            self.progressAlertHandler = progressHandler

            self.dismiss(animated: true, completion: nil)
            self.startImex(what: DC_IMEX_EXPORT_BACKUP)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @objc private func handleReceiptConfirmationToggle(_ sender: UISwitch) {
        dcContext.mdnsEnabled = sender.isOn
    }

    // MARK: - updates
    private func startImex(what: Int32, passphrase: String? = nil) {
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if !documents.isEmpty {
            progressAlertHandler?.showProgressAlert(title: String.localized("export_backup_desktop"), dcContext: dcContext)
            DispatchQueue.main.async {
                self.dcAccounts.stopIo()
                self.dcContext.imex(what: what, directory: documents[0], passphrase: passphrase)
            }
        } else {
            logger.error("document directory not found")
        }
    }

    private func updateCells() {
        tableView.reloadData() // needed to update footer
        mediaQualityCell.detailTextLabel?.text = MediaQualityViewController.getValString(val: dcContext.getConfigInt("media_quality"))
        downloadOnDemandCell.detailTextLabel?.text = DownloadOnDemandViewController.getValString(
            val: dcContext.getConfigInt("download_limit"))
        autodelDeviceCell.detailTextLabel?.text = AutodelOptionsViewController.getSummary(dcContext, fromServer: false)
        autodelServerCell.detailTextLabel?.text = AutodelOptionsViewController.getSummary(dcContext, fromServer: true)
    }

    // MARK: - coordinator
    private func  showMediaQuality() {
        let mediaQualityController = MediaQualityViewController(dcContext: dcContext)
        navigationController?.pushViewController(mediaQualityController, animated: true)
    }

    private func showDownloadOnDemand() {
        let downloadOnDemandViewController = DownloadOnDemandViewController(dcContext: dcContext)
        navigationController?.pushViewController(downloadOnDemandViewController, animated: true)
    }

    private func showBlockedContacts() {
        let blockedContactsController = BlockedContactsViewController(dcContext: dcContext)
        navigationController?.pushViewController(blockedContactsController, animated: true)
    }
}

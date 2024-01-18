import UIKit
import DcCore
import Intents

internal final class ChatsAndMediaViewController: UITableViewController, ProgressAlertHandler {

    private struct SectionConfigs {
        let headerTitle: String?
        let footerTitle: String?
        let cells: [UITableViewCell]
    }

    private enum CellTags: Int {
        case showEmails
        case blockedContacts
        case receiptConfirmation
        case exportBackup
        case autodel
        case mediaQuality
        case downloadOnDemand
    }

    private var dcContext: DcContext
    internal let dcAccounts: DcAccounts

    // MARK: - ProgressAlertHandler
    weak var progressAlert: UIAlertController?
    var progressObserver: NSObjectProtocol?

    // MARK: - cells
    private lazy var showEmailsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.showEmails.rawValue
        cell.textLabel?.text = String.localized("pref_show_emails")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = EmailOptionsViewController.getValString(val: dcContext.showEmails)
        return cell
    }()

    private lazy var blockedContactsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.blockedContacts.rawValue
        cell.textLabel?.text = String.localized("pref_blocked_contacts")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    func autodelSummary() -> String {
        let delDeviceAfter = dcContext.getConfigInt("delete_device_after")
        let delServerAfter = dcContext.getConfigInt("delete_server_after")
        if delDeviceAfter==0 && delServerAfter==0 {
            return String.localized("never")
        } else {
            return String.localized("on")
        }
    }

    private lazy var autodelCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.autodel.rawValue
        cell.textLabel?.text = String.localized("delete_old_messages")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = autodelSummary()
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
            cells: [showEmailsCell, blockedContactsCell, mediaQualityCell, downloadOnDemandCell,
                    autodelCell, receiptConfirmationCell]
        )
        let exportBackupSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: String.localized("pref_backup_explain"),
            cells: [exportBackupCell]
        )
        return [preferencesSection, exportBackupSection]
    }()

    init(dcAccounts: DcAccounts) {
        self.dcContext = dcAccounts.getSelected()
        self.dcAccounts = dcAccounts
        super.init(style: .grouped)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("pref_chats_and_media")
        tableView.rowHeight = UITableView.automaticDimension
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateCells()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addProgressAlertListener(dcAccounts: dcAccounts, progressName: eventImexProgress) { [weak self] in
            guard let self else { return }

            self.progressAlert?.dismiss(animated: true) {
                let alert = UIAlertController(
                    title: String.localized("backup_successful"),
                    message: String.localizedStringWithFormat(String.localized("backup_successful_explain_ios"), "\(String.localized("Files")) ➔ Delta Chat"),
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let nc = NotificationCenter.default
        if let backupProgressObserver = self.progressObserver {
            nc.removeObserver(backupProgressObserver)
        }
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
            safe_fatalError()
            return
        }
        tableView.deselectRow(at: indexPath, animated: false)

        switch cellTag {
        case .showEmails: showClassicMail()
        case .blockedContacts: showBlockedContacts()
        case .autodel: showAutodelOptions()
        case .mediaQuality: showMediaQuality()
        case .downloadOnDemand: showDownloadOnDemand()
        case .receiptConfirmation: break
        case .exportBackup: createBackup()
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerTitle
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
    }

    // MARK: - actions

    private func createBackup() {
        let alert = UIAlertController(title: String.localized("pref_backup_export_explain"), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("pref_backup_export_start_button"), style: .default, handler: { _ in
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
            showProgressAlert(title: String.localized("export_backup_desktop"), dcContext: dcContext)
            DispatchQueue.main.async {
                self.dcAccounts.stopIo()
                self.dcContext.imex(what: what, directory: documents[0], passphrase: passphrase)
            }
        } else {
            logger.error("document directory not found")
        }
    }

    private func updateCells() {
        showEmailsCell.detailTextLabel?.text = EmailOptionsViewController.getValString(val: dcContext.showEmails)
        mediaQualityCell.detailTextLabel?.text = MediaQualityViewController.getValString(val: dcContext.getConfigInt("media_quality"))
        downloadOnDemandCell.detailTextLabel?.text = DownloadOnDemandViewController.getValString(
            val: dcContext.getConfigInt("download_limit"))
        autodelCell.detailTextLabel?.text = autodelSummary()
    }

    // MARK: - coordinator
    private func showClassicMail() {
        let settingsClassicViewController = EmailOptionsViewController(dcContext: dcContext)
        navigationController?.pushViewController(settingsClassicViewController, animated: true)
    }

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

    private func showAutodelOptions() {
        let settingsAutodelOverviewController = AutodelOverviewViewController(dcContext: dcContext)
        navigationController?.pushViewController(settingsAutodelOverviewController, animated: true)
    }
}

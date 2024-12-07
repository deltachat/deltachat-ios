import UIKit
import DcCore
import Intents

internal final class NotificationsViewController: UITableViewController {

    private struct SectionConfigs {
        let headerTitle: String?
        let footerTitle: String?
        let cells: [UITableViewCell]
    }

    private enum CellTags: Int {
        case defaultTagValue = 0
        case systemSettings
    }

    private var dcContext: DcContext
    internal let dcAccounts: DcAccounts

    // MARK: - cells
    private lazy var notificationsCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_notifications"),
            on: !dcContext.isMuted(),
            action: { [weak self] cell in
                guard let self else { return }

                dcContext.setMuted(!cell.isOn)
                if cell.isOn {
                    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                        appDelegate.registerForNotifications()
                    }
                } else {
                    NotificationManager.removeAllNotifications()
                }

                updateCells()
                NotificationManager.updateBadgeCounters()
                NotificationCenter.default.post(name: Event.messagesChanged, object: nil, userInfo: ["message_id": Int(0), "chat_id": Int(0)])
        })
    }()

    private lazy var mentionsCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_mention_notifications"),
            on: false, // set in updateCells()
            action: { [weak self] cell in
                self?.dcContext.setMentionsEnabled(cell.isOn)
        })
    }()

    private lazy var systemSettingsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.systemSettings.rawValue
        cell.textLabel?.text = String.localized("system_settings")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var sections: [SectionConfigs] = {
        let preferencesSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: String.localized("pref_mention_notifications_explain"),
            cells: [notificationsCell, mentionsCell]
        )
        let systemSettingsSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: String.localized("system_settings_notify_explain_ios"),
            cells: [systemSettingsCell]
        )
        return [preferencesSection, systemSettingsSection]
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
        title = String.localized("pref_notifications")
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

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerTitle
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath), let cellTag = CellTags(rawValue: cell.tag) else { safe_fatalError(); return }
        tableView.deselectRow(at: indexPath, animated: false)

        switch cellTag {
        case .systemSettings:
            let urlString = if #available(iOS 16, *) {
                UIApplication.openNotificationSettingsURLString
            } else if #available(iOS 15.4, *) {
                UIApplicationOpenNotificationSettingsURLString
            } else {
                UIApplication.openSettingsURLString
            }

            if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        case .defaultTagValue:
            break
        }
    }

    private func updateCells() {
        mentionsCell.uiSwitch.isEnabled = !dcContext.isMuted()
        mentionsCell.uiSwitch.isOn = !dcContext.isMuted() && dcContext.isMentionsEnabled
    }
}

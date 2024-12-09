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
        case notifications
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

                NotificationManager.updateBadgeCounters()
                NotificationCenter.default.post(name: Event.messagesChanged, object: nil, userInfo: ["message_id": Int(0), "chat_id": Int(0)])
        })
    }()

    private lazy var mentionsCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_mention_notifications"),
            on: dcContext.isMentionsEnabled(),
            action: { [weak self] cell in
                self?.dcContext.setMentionsEnabled(cell.isOn)
        })
    }()

    private lazy var sections: [SectionConfigs] = {
        let preferencesSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: String.localized("pref_mention_notifications_explain"),
            cells: [notificationsCell, mentionsCell]
        )
        return [preferencesSection]
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
        title = String.localized("pref_notifications")
        tableView.rowHeight = UITableView.automaticDimension
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
}

import UIKit
import DcCore
class SettingsEphemeralMessageController: UITableViewController {

    var dcContext: DcContext
    var chatId: Int

    lazy var options: [Int] = {
        return [0, Time.thirtySeconds, Time.oneMinute, Time.oneHour, Time.oneDay, Time.oneWeek, Time.fourWeeks]
    }()

    var staticCells: [UITableViewCell] {
        return options.map({
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = SettingsEphemeralMessageController.getValString(val: $0)
            cell.selectionStyle = .none
            return cell
        })
    }

    var selectedIndex: Int {
        if let index = self.options.index(of: dcContext.getChatEphemeralTimer(chatId: chatId)) {
            return index
        }
        //default to off
        return 0
    }

    init(dcContext: DcContext, chatId: Int) {
        self.dcContext = dcContext
        self.chatId = chatId
        super.init(style: .grouped)
        self.title = String.localized("pref_show_emails")
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static public func getValString(val: Int) -> String {
        switch val {
        case 0:
            return String.localized("off")
        case Time.thirtySeconds:
            return String.localized("after_30_seconds")
        case Time.oneMinute:
            return String.localized("after_1_minute")
        case Time.oneHour:
            return String.localized("autodel_after_1_hour")
        case Time.oneDay:
            return String.localized("autodel_after_1_day")
        case Time.oneWeek:
            return String.localized("autodel_after_1_week")
        case Time.fourWeeks:
            return String.localized("autodel_after_4_weeks")
        default:
            return "Err"
        }
    }


    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let oldSelectedCell = tableView.cellForRow(at: IndexPath.init(row: selectedIndex, section: 0))
        oldSelectedCell?.accessoryType = .none

        let newSelectedCell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row, section: 0))
        newSelectedCell?.accessoryType = .checkmark

        dcContext.setChatEphemeralTimer(chatId: chatId, duration: options[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = staticCells[indexPath.row]
        if selectedIndex == indexPath.row {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }
}

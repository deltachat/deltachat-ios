import UIKit
import DcCore
class EphemeralMessagesViewController: UITableViewController {

    var dcContext: DcContext
    var chatId: Int
    var currentIndex: Int = 0

    private lazy var options: [Int] = {
        return [0, Time.fiveMinutes, Time.oneHour, Time.oneDay, Time.oneWeek, Time.fiveWeeks, Time.oneYear]
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        let button =  UIBarButtonItem(title: String.localized("cancel"), style: .plain, target: self, action: #selector(cancelButtonPressed))
        return button
    }()

    private lazy var okButton: UIBarButtonItem = {
        let button =  UIBarButtonItem(title: String.localized("ok"), style: .done, target: self, action: #selector(okButtonPressed))
        return button
    }()

    private var staticCells: [UITableViewCell] {
        return options.map({
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = EphemeralMessagesViewController.getValString(val: $0)
            return cell
        })
    }

    init(dcContext: DcContext, chatId: Int) {
        self.dcContext = dcContext
        self.chatId = chatId
        super.init(style: .insetGrouped)

        // select option close to the timespan (that may no be available as an option eg. in case option have changed)
        self.currentIndex = 0
        let timespan = dcContext.getChatEphemeralTimer(chatId: chatId)
        if timespan > 0 {
            self.currentIndex = options.count - 1
            for i in 2...options.count - 1 {
                if timespan < options[i] {
                    self.currentIndex = i - 1
                    break
                }
            }
        }

        self.title = String.localized("ephemeral_messages")
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

    public static func getValString(val: Int) -> String? {
        switch val {
        case 0:
            return String.localized("off")
        case Time.fiveMinutes:
            return String.localized("after_5_minutes")
        case Time.oneHour:
            return String.localized("autodel_after_1_hour")
        case Time.oneDay:
            return String.localized("autodel_after_1_day")
        case Time.oneWeek:
            return String.localized("autodel_after_1_week")
        case Time.fiveWeeks:
            return String.localized("after_5_weeks")
        case Time.oneYear:
            return String.localized("autodel_after_1_year")
        default:
            return nil
        }
    }

    @objc private func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func okButtonPressed() {
        dcContext.setChatEphemeralTimer(chatId: chatId, duration: options[currentIndex])

        // pop two view controllers:
        // go directly back to the chatview where also the confirmation message will be shown
        navigationController?.popViewControllers(viewsToPop: 2, animated: true)
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if !dcContext.getChat(chatId: chatId).isSelfTalk { // the hint refers to "all member of the chat", this is weird for "Saved Messages"
            return String.localized("ephemeral_messages_hint")
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true) // animated as no other elements pop up

        let oldSelectedCell = tableView.cellForRow(at: IndexPath.init(row: currentIndex, section: 0))
        oldSelectedCell?.accessoryType = .none

        let newSelectedCell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row, section: 0))
        newSelectedCell?.accessoryType = .checkmark

        currentIndex = indexPath.row
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = staticCells[indexPath.row]
        if currentIndex == indexPath.row {
            cell.accessoryType = .checkmark
        }
        return cell
    }
}

import UIKit
import DcCore

class MessageInfoViewController: UITableViewController {
    var dcContext: DcContext
    var message: DcMsg
    private static let reuseIdentifier = "MessageInfoCell"

    init(dcContext: DcContext, message: DcMsg) {
        self.dcContext = dcContext
        self.message = message
        super.init(style: .grouped)

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: MessageInfoViewController.reuseIdentifier)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("menu_message_details")
    }

    // MARK: - Table view data source

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1 // number of rows in section
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MessageInfoViewController.reuseIdentifier, for: indexPath)

        if indexPath.section == 0 {
            if indexPath.row == 0 {
                cell.textLabel?.numberOfLines = 0
                cell.textLabel?.lineBreakMode = .byWordWrapping
                cell.textLabel?.text = dcContext.getMsgInfo(msgId: message.id)
            }
        }

        return cell
    }
}

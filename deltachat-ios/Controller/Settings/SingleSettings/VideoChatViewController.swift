import UIKit
import DcCore
class VideoChatViewController: UITableViewController {

    private var dcContext: DcContext

    private lazy var videoInstanceCell: TextFieldCell = {
        let cell = TextFieldCell.makeConfigCell(labelID: String.localized("videochat_instance"),
                                                placeholderID: String.localized("videochat_instance_placeholder"))
        cell.textField.autocapitalizationType = .none
        cell.textField.autocorrectionType = .no
        cell.textField.textContentType = .URL
        return cell
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(style: .grouped)
        self.title = String.localized("videochat_instance")
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        videoInstanceCell.textField.text = dcContext.getConfig("webrtc_instance")
        return videoInstanceCell
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return String.localized("videochat_instance_explain_2") + "\n\n" + String.localized("videochat_instance_example")
    }

    override func viewWillDisappear(_ animated: Bool) {
        dcContext.setConfig("webrtc_instance", videoInstanceCell.getText())
    }
}

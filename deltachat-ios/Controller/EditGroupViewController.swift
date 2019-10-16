import UIKit

class EditGroupViewController: UITableViewController {

    weak var coordinator: EditGroupCoordinator?

    private let chat: DcChat

    var groupNameCell: GroupLabelCell

    lazy var doneButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(saveContactButtonPressed))
        button.isEnabled = false
        return button
    }()

    lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        return button
    }()

    init(chat: DcChat) {
        self.chat = chat
        self.groupNameCell = GroupLabelCell(chat: chat)
        super.init(style: .grouped)
        groupNameCell.inputField.text = chat.name
        self.groupNameCell.onTextChanged = groupNameEdited(_:)
        self.groupNameCell.selectionStyle = .none
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = doneButton
        navigationItem.leftBarButtonItem = cancelButton
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return groupNameCell
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    @objc func saveContactButtonPressed() {
        let newName = groupNameCell.getGroupName()
        dc_set_chat_name(mailboxPointer, UInt32(chat.id), newName)
        coordinator?.navigateBack()
    }

    @objc func cancelButtonPressed() {
        coordinator?.navigateBack()
    }

    private func groupNameEdited(_ newName: String) {
        doneButton.isEnabled = true
    }
}

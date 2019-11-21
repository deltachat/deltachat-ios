import UIKit

class EditGroupViewController: UITableViewController {

    weak var coordinator: EditGroupCoordinator?

    private let chat: DcChat

    private let rowAvatar = 0
    private let rowGroupName = 1

    var avatarSelectionCell: AvatarSelectionCell

    lazy var groupNameCell: TextFieldCell = {
        let cell = TextFieldCell(description: String.localized("group_name"), placeholder: self.chat.name)
        cell.setText(text: self.chat.name)
        cell.onTextFieldChange = self.groupNameEdited(_:)
        return cell
    }()

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
        self.avatarSelectionCell = AvatarSelectionCell(chat: chat)
        super.init(style: .grouped)
        self.avatarSelectionCell.selectionStyle = .none
        self.avatarSelectionCell.hintLabel.text = String.localized("group_avatar")
        title = String.localized("menu_edit_group")
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
        if indexPath.row == rowAvatar {
            return avatarSelectionCell
        } else {
            return groupNameCell
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == rowAvatar {
            return AvatarSelectionCell.cellSize
        }
        return Constants.stdCellHeight
    }
    
    @objc func saveContactButtonPressed() {
        let newName = groupNameCell.getText()
        dc_set_chat_name(mailboxPointer, UInt32(chat.id), newName)
        coordinator?.navigateBack()
    }

    @objc func cancelButtonPressed() {
        coordinator?.navigateBack()
    }

    private func groupNameEdited(_ textField: UITextField) {
        avatarSelectionCell.onInitialsChanged(text: textField.text)
        doneButton.isEnabled = true
    }
}

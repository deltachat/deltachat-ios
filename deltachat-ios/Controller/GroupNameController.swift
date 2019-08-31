import UIKit

class GroupNameController: UITableViewController {
    weak var coordinator: GroupNameCoordinator?

    var groupName: String = ""

    var doneButton: UIBarButtonItem!
    let contactIdsForGroup: Set<Int> // TODO: check if array is sufficient
    let groupContactIds: [Int]

    init(contactIdsForGroup: Set<Int>) {
        self.contactIdsForGroup = contactIdsForGroup
        groupContactIds = Array(contactIdsForGroup)
        super.init(style: .grouped)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("menu_new_group")
        doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonPressed))
        navigationItem.rightBarButtonItem = doneButton
        tableView.bounces = false
        doneButton.isEnabled = false
        tableView.register(GroupLabelCell.self, forCellReuseIdentifier: "groupLabelCell")
        tableView.register(ContactCell.self, forCellReuseIdentifier: "contactCell")
        // setupSubviews()
    }

    @objc func doneButtonPressed() {
        let groupChatId = dc_create_group_chat(mailboxPointer, 0, groupName)
        for contactId in contactIdsForGroup {
            let success = dc_add_contact_to_chat(mailboxPointer, groupChatId, UInt32(contactId))
            if success == 1 {
                logger.info("successfully added \(contactId) to group \(groupName)")
            } else {
                // FIXME:
                fatalError("failed to add \(contactId) to group \(groupName)")
            }
        }

        coordinator?.showGroupChat(chatId: Int(groupChatId))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func numberOfSections(in _: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        let row = indexPath.row

        if section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "groupLabelCell", for: indexPath)
            if let groupLabelCell = cell as? GroupLabelCell {
                groupLabelCell.onTextChanged = updateGroupName
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "contactCell", for: indexPath)
            if let contactCell = cell as? ContactCell {
                let contact = DcContact(id: groupContactIds[row])
                let displayName = contact.displayName
                contactCell.nameLabel.text = displayName
                contactCell.emailLabel.text = contact.email
                contactCell.initialsLabel.text = Utils.getInitials(inputName: displayName)
                contactCell.setColor(contact.color)
            }
            return cell
        }
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return contactIdsForGroup.count
        }
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            return String.localized("in_this_group_desktop")
        } else {
            return nil
        }
    }

    private func updateGroupName(name: String) {
        groupName = name
        doneButton.isEnabled = name.containsCharacters()
    }
}

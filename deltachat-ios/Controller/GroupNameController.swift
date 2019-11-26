import UIKit

class GroupNameController: UITableViewController, MediaPickerDelegate {

    weak var coordinator: GroupNameCoordinator?

    var groupName: String = ""

    var doneButton: UIBarButtonItem!
    let contactIdsForGroup: Set<Int> // TODO: check if array is sufficient
    let groupContactIds: [Int]
    var groupImage: UIImage?

    private let sectionGroupDetails = 0
    private let sectionGroupDetailsRowAvatar = 0
    private let sectionGroupDetailsRowName = 1
    private let countSectionGroupDetails = 2

    lazy var groupNameCell: TextFieldCell = {
        let cell = TextFieldCell(description: String.localized("group_name"), placeholder: String.localized("menu_edit_group_name"))
        cell.onTextFieldChange = self.updateGroupName
        return cell
    }()

    lazy var avatarSelectionCell: AvatarSelectionCell = {
        let cell = AvatarSelectionCell(context: nil)
        cell.hintLabel.text = String.localized("group_avatar")
        cell.onAvatarTapped = onAvatarTapped
        return cell
    }()    

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
        tableView.register(ContactCell.self, forCellReuseIdentifier: "contactCell")
    }

    @objc func doneButtonPressed() {
        let groupChatId = dc_create_group_chat(mailboxPointer, 0, groupName)
        for contactId in contactIdsForGroup {
            let success = dc_add_contact_to_chat(mailboxPointer, groupChatId, UInt32(contactId))

            if let groupImage = groupImage, let dcContext = coordinator?.dcContext {
                    AvatarHelper.saveChatAvatar(dcContext: dcContext, image: groupImage, for: Int(groupChatId))
            }

            if success == 1 {
                logger.info("successfully added \(contactId) to group \(groupName)")
            } else {
                logger.error("failed to add \(contactId) to group \(groupName)")
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

        if section == sectionGroupDetails {
            if row == sectionGroupDetailsRowAvatar {
                return avatarSelectionCell
            } else {
                return groupNameCell
            }
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

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = indexPath.section
        let row = indexPath.row
        if section == sectionGroupDetails {
            if row == sectionGroupDetailsRowAvatar {
                return AvatarSelectionCell.cellSize
            } else {
                return Constants.stdCellHeight
            }
        } else {
            return ContactCell.cellSize
        }
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == sectionGroupDetails {
            return countSectionGroupDetails
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

    private func updateGroupName(textView: UITextField) {
        let name = textView.text ?? ""
        groupName = name
        doneButton.isEnabled = name.containsCharacters()
    }

    private func onAvatarTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            let photoAction = PhotoPickerAlertAction(title: String.localized("gallery"), style: .default, handler: galleryButtonPressed(_:))
            let videoAction = PhotoPickerAlertAction(title: String.localized("camera"), style: .default, handler: cameraButtonPressed(_:))
            alert.addAction(photoAction)
            alert.addAction(videoAction)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func galleryButtonPressed(_ action: UIAlertAction) {
        coordinator?.showPhotoPicker(delegate: self)
    }

    private func cameraButtonPressed(_ action: UIAlertAction) {
        coordinator?.showCamera(delegate: self)
    }

    func onImageSelected(image: UIImage) {
        groupImage = image

        avatarSelectionCell = AvatarSelectionCell(context: nil, with: groupImage)
        avatarSelectionCell.hintLabel.text = String.localized("group_avatar")
        avatarSelectionCell.onAvatarTapped = onAvatarTapped

        self.tableView.beginUpdates()
        let indexPath = IndexPath(row: sectionGroupDetailsRowAvatar, section: sectionGroupDetails)
        self.tableView.reloadRows(at: [indexPath], with: UITableView.RowAnimation.none)
        self.tableView.endUpdates()
    }

    func onDismiss() {
        
    }

}

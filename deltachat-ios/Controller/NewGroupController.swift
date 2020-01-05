import UIKit

class NewGroupController: UITableViewController, MediaPickerDelegate {

    weak var coordinator: NewGroupCoordinator?

    var groupName: String = ""
    var groupChatId: Int = 0

    var doneButton: UIBarButtonItem!
    var contactIdsForGroup: Set<Int> // TODO: check if array is sufficient
    var groupContactIds: [Int]
    var groupImage: UIImage?
    let isVerifiedGroup: Bool
    let dcContext: DcContext

    private let sectionGroupDetails = 0
    private let sectionGroupDetailsRowAvatar = 0
    private let sectionGroupDetailsRowName = 1
    private let countSectionGroupDetails = 2
    private let sectionInvite = 1
    private let sectionInviteRowAddMembers = 0
    private let sectionInviteRowShowQrCode = 1
    private lazy var countSectionInvite: Int = 2
    private let sectionGroupMembers = 2

    lazy var groupNameCell: TextFieldCell = {
        let cell = TextFieldCell(description: String.localized("group_name"), placeholder: String.localized("group_name"))
        cell.onTextFieldChange = self.updateGroupName
        return cell
    }()

    lazy var avatarSelectionCell: AvatarSelectionCell = {
        let cell = AvatarSelectionCell(context: nil)
        cell.hintLabel.text = String.localized("group_avatar")
        cell.onAvatarTapped = onAvatarTapped
        return cell
    }()

    var qrInviteCodeCell: ActionCell?

    init(dcContext: DcContext, isVerified: Bool) {
        self.contactIdsForGroup = [Int(DC_CONTACT_ID_SELF)]
        self.groupContactIds = Array(contactIdsForGroup)
        self.isVerifiedGroup = isVerified
        self.dcContext = dcContext
        super.init(style: .grouped)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = isVerifiedGroup ? String.localized("menu_new_verified_group") : String.localized("menu_new_group")
        doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonPressed))
        navigationItem.rightBarButtonItem = doneButton
        tableView.bounces = false
        doneButton.isEnabled = false
        tableView.register(ContactCell.self, forCellReuseIdentifier: "contactCell")
        tableView.register(ActionCell.self, forCellReuseIdentifier: "actionCell")
        self.hideKeyboardOnTap() 
    }

    override func viewWillAppear(_ animated: Bool) {
        if groupChatId != 0 {
            let chat = DcChat.init(id: groupChatId)
            updateGroupContactIds(Set(chat.contactIds))
        }
    }

    @objc func doneButtonPressed() {
        if groupChatId == 0 {
            groupChatId = dcContext.createGroupChat(verified: isVerifiedGroup, name: groupName)
        } else {
            _ = dcContext.setChatName(chatId: groupChatId, name: groupName)
        }

        for contactId in contactIdsForGroup {
            let success = dcContext.addContactToChat(chatId: groupChatId, contactId: contactId)

            if let groupImage = groupImage, let dcContext = coordinator?.dcContext {
                    AvatarHelper.saveChatAvatar(dcContext: dcContext, image: groupImage, for: Int(groupChatId))
            }

            if success {
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
        return 3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        let row = indexPath.row

        switch section {
        case sectionGroupDetails:
             if row == sectionGroupDetailsRowAvatar {
                return avatarSelectionCell
            } else {
                return groupNameCell
            }
        case sectionInvite:
            if row == sectionInviteRowAddMembers {
                let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
                if let actionCell = cell as? ActionCell {
                    actionCell.actionTitle = String.localized("group_add_members")
                    actionCell.actionColor = UIColor.systemBlue
                    actionCell.isUserInteractionEnabled = true
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
                if let actionCell = cell as? ActionCell {
                    actionCell.actionTitle = String.localized("qrshow_join_group_title")
                    actionCell.actionColor = groupName.isEmpty ? DcColors.colorDisabled : UIColor.systemBlue
                    actionCell.isUserInteractionEnabled = !groupName.isEmpty
                    qrInviteCodeCell = actionCell
                }
                return cell
            }
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "contactCell", for: indexPath)
            if let contactCell = cell as? ContactCell {
                let contact = DcContact(id: groupContactIds[row])
                let displayName = contact.displayName
                contactCell.nameLabel.text = displayName
                contactCell.emailLabel.text = contact.email
                contactCell.avatar.setName(displayName)
                contactCell.avatar.setColor(contact.color)
                if let profileImage = contact.profileImage {
                    contactCell.avatar.setImage(profileImage)
                }
                contactCell.setVerified(isVerified: contact.isVerified)
            }
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == sectionGroupDetails && isVerifiedGroup {
            return String.localized("verified_group_explain")
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = indexPath.section
        let row = indexPath.row
        switch section {
        case sectionGroupDetails:
            if row == sectionGroupDetailsRowAvatar {
                return AvatarSelectionCell.cellSize
            } else {
                return Constants.defaultCellHeight
            }
        case sectionInvite:
            return Constants.defaultCellHeight
        default:
            return ContactCell.cellHeight
        }
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case sectionGroupDetails:
            return countSectionGroupDetails
        case sectionInvite:
            return countSectionInvite
        default:
            return contactIdsForGroup.count
        }
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == sectionGroupMembers {
            return String.localized("in_this_group_desktop")
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = indexPath.section
        let row = indexPath.row
        if section == sectionInvite {
            if row == sectionInviteRowAddMembers {
                var contactsWithoutSelf = contactIdsForGroup
                contactsWithoutSelf.remove(Int(DC_CONTACT_ID_SELF))
                coordinator?.showAddMembers(preselectedMembers: contactsWithoutSelf, isVerified: self.isVerifiedGroup)
            } else {
                self.groupChatId = dcContext.createGroupChat(verified: isVerifiedGroup, name: groupName)
                coordinator?.showQrCodeInvite(chatId: Int(self.groupChatId))
            }
        }
    }

    private func updateGroupName(textView: UITextField) {
        let name = textView.text ?? ""
        groupName = name
        doneButton.isEnabled = name.containsCharacters()
        qrInviteCodeCell?.isUserInteractionEnabled = name.containsCharacters()
        qrInviteCodeCell?.actionColor = groupName.isEmpty ? DcColors.colorDisabled : UIColor.systemBlue
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

    func updateGroupContactIds(_ members: Set<Int>) {
        contactIdsForGroup = members
        groupContactIds = Array(members)
        self.tableView.reloadData()
    }
}

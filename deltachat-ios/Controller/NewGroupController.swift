import UIKit
import DcCore

class NewGroupController: UITableViewController, MediaPickerDelegate {

    var doneButton: UIBarButtonItem!
    var contactIdsForGroup: Set<Int>
    var groupContactIds: [Int]
    let templateChat: DcChat?

    private var changeGroupImage: UIImage?
    private var deleteGroupImage: Bool = false

    enum CreateMode {
        case createGroup
        case createBroadcast
        case createEmail
    }
    private let createMode: CreateMode

    let dcContext: DcContext

    enum DetailsRows {
        case name
        case avatar
    }
    private let detailsRows: [DetailsRows]

    enum InviteRows {
        case addMembers
    }
    private let inviteRows: [InviteRows]

    enum NewGroupSections {
        case details
        case invite
        case members
    }
    private let sections: [NewGroupSections]

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(dcContext: dcContext, navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    lazy var groupNameCell: TextFieldCell = {
        let (title, placeholder) = switch createMode {
        case .createBroadcast: ("channel_name", "name_desktop")
        case .createEmail: ("subject", "subject")
        case .createGroup: ("group_name", "name_desktop")
        }
        let cell = TextFieldCell(description: String.localized(title), placeholder: String.localized(placeholder))
        cell.onTextFieldChange = self.updateGroupName
        cell.textField.autocorrectionType = UITextAutocorrectionType.no
        cell.textField.enablesReturnKeyAutomatically = true
        cell.textField.returnKeyType = .default
        cell.textFieldDelegate = self
        return cell
    }()

    lazy var avatarSelectionCell: AvatarSelectionCell = {
        let cell = AvatarSelectionCell(image: nil)
        cell.hintLabel.text = String.localized(createMode == .createGroup ? "group_avatar" : "image")
        cell.onAvatarTapped = onAvatarTapped
        return cell
    }()

    init(dcContext: DcContext, createMode: CreateMode, templateChatId: Int? = nil) {
        self.createMode = createMode
        self.dcContext = dcContext
        if createMode == .createEmail {
            self.detailsRows = [.name]
        } else {
            self.detailsRows = [.name, .avatar]
        }
        self.inviteRows = [.addMembers]
        if createMode == .createBroadcast {
            self.sections = [.details, .members]
            self.contactIdsForGroup = []
        } else {
            self.sections = [.details, .invite, .members]
            self.contactIdsForGroup = [Int(DC_CONTACT_ID_SELF)]
        }
        if let templateChatId = templateChatId {
            templateChat = dcContext.getChat(chatId: templateChatId)
            if let templateChat = templateChat {
                self.contactIdsForGroup = Set(templateChat.getContactIds(dcContext))
            }
        } else {
            templateChat = nil
        }
        self.groupContactIds = Array(contactIdsForGroup)
        super.init(style: .insetGrouped)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        switch createMode {
        case .createGroup: title = String.localized("menu_new_group")
        case .createBroadcast: title = String.localized("new_channel")
        case .createEmail: title = String.localized("new_email")
        }
        if let templateChat = self.templateChat {
            groupNameCell.textField.text = templateChat.name
            if let image = templateChat.profileImage {
                avatarSelectionCell = AvatarSelectionCell(image: image)
                changeGroupImage = image
            }
        }
        doneButton = UIBarButtonItem(title: String.localized(createMode == .createEmail ? "perm_continue" : "create"), style: .done, target: self, action: #selector(doneButtonPressed))
        navigationItem.rightBarButtonItem = doneButton
        tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseIdentifier)
        tableView.register(ActionCell.self, forCellReuseIdentifier: ActionCell.reuseIdentifier)
        self.hideKeyboardOnTap()
        checkDoneButton()
    }

    private func checkDoneButton() {
        let name = groupNameCell.textField.text ?? ""
        let nameOk = !name.isEmpty
        doneButton.isEnabled = nameOk
    }

    private func allMembersVerified() -> Bool {
        for contactId in contactIdsForGroup {
            if !dcContext.getContact(id: contactId).isVerified {
                return false
            }
        }
        return true
    }

    @objc func doneButtonPressed() {
        guard let groupName = groupNameCell.textField.text else { return }
        let groupChatId = switch createMode {
        case .createBroadcast: dcContext.createBroadcast(name: groupName)
        case .createEmail: dcContext.createGroupChatUnencrypted(name: groupName)
        case .createGroup: dcContext.createGroupChat(verified: allMembersVerified(), name: groupName)
        }

        for contactId in contactIdsForGroup {
            _ = dcContext.addContactToChat(chatId: groupChatId, contactId: contactId)
        }
        if let groupImage = changeGroupImage {
            AvatarHelper.saveChatAvatar(dcContext: dcContext, image: groupImage, for: groupChatId)
        } else if deleteGroupImage {
            AvatarHelper.saveChatAvatar(dcContext: dcContext, image: nil, for: groupChatId)
        }

        showGroupChat(chatId: Int(groupChatId))
    }


    override func numberOfSections(in _: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row

        switch sections[indexPath.section] {
        case .details:
            if detailsRows[row] == .avatar {
                return avatarSelectionCell
            } else {
                return groupNameCell
            }
        case .invite:
            guard let actionCell = tableView.dequeueReusableCell(withIdentifier: ActionCell.reuseIdentifier, for: indexPath) as? ActionCell else { fatalError("No ActionCell") }
            if inviteRows[row] == .addMembers {
                actionCell.imageView?.image = UIImage(systemName: "plus")
                actionCell.actionTitle = String.localized("group_add_members")
                actionCell.actionColor = UIColor.systemBlue
                actionCell.isUserInteractionEnabled = true
            }
            return actionCell
        case .members:
            guard let contactCell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseIdentifier, for: indexPath) as? ContactCell else { fatalError("No ContactCell") }

            let contact = dcContext.getContact(id: groupContactIds[row])
            let displayName = contact.displayName
            contactCell.titleLabel.text = displayName
            contactCell.subtitleLabel.text = contact.email
            contactCell.avatar.setName(displayName)
            contactCell.avatar.setColor(contact.color)
            if let profileImage = contact.profileImage {
                contactCell.avatar.setImage(profileImage)
            }
            contactCell.selectionStyle = .none
            return contactCell
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if sections[section] == .details && createMode == .createBroadcast {
            return String.localized("chat_new_channel_hint")
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch sections[indexPath.section] {
        case .details, .invite:
            return UITableView.automaticDimension
        case .members:
            return ContactCell.cellHeight
        }
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .details:
            return detailsRows.count
        case .invite:
            return inviteRows.count
        case .members:
            return contactIdsForGroup.count
        }
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        if sections[section] == .members && !contactIdsForGroup.isEmpty {
            if createMode == .createGroup {
                return String.localized(stringID: "n_members", parameter: contactIdsForGroup.count)
            } else {
                return String.localized(stringID: "n_recipients", parameter: contactIdsForGroup.count)
            }
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if sections[indexPath.section] == .invite {
            tableView.deselectRow(at: indexPath, animated: false)
            if inviteRows[indexPath.row] == .addMembers {
                var contactsWithoutSelf = contactIdsForGroup
                contactsWithoutSelf.remove(Int(DC_CONTACT_ID_SELF))
                showAddMembers(preselectedMembers: contactsWithoutSelf)
            }
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if sections[indexPath.section] == .members, groupContactIds[indexPath.row] != DC_CONTACT_ID_SELF {
            let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completionHandler in
                guard let self else { return }
                self.removeGroupContactFromList(at: indexPath)
                completionHandler(true)
            }
            deleteAction.accessibilityLabel = String.localized("remove_desktop")
            deleteAction.image = Utils.makeImageWithText(image: UIImage(systemName: "trash"), text: String.localized("remove_desktop"))
            return UISwipeActionsConfiguration(actions: [deleteAction])
        } else {
            return nil
        }
    }

    private func updateGroupName(textView: UITextField) {
        checkDoneButton()
    }

    private func onAvatarTapped() {
        let alert = UIAlertController(title: String.localized(createMode == .createGroup ? "group_avatar" : "image"), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(PhotoPickerAlertAction(title: String.localized("camera"), style: .default, handler: cameraButtonPressed(_:)))
            alert.addAction(PhotoPickerAlertAction(title: String.localized("gallery"), style: .default, handler: galleryButtonPressed(_:)))
            if avatarSelectionCell.isAvatarSet() {
                alert.addAction(UIAlertAction(title: String.localized("delete"), style: .destructive, handler: deleteGroupAvatarPressed(_:)))
            }
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func galleryButtonPressed(_ action: UIAlertAction) {
        showPhotoPicker(delegate: self)
    }

    private func cameraButtonPressed(_ action: UIAlertAction) {
        showCamera(delegate: self)
    }

    private func deleteGroupAvatarPressed(_ action: UIAlertAction) {
        changeGroupImage = nil
        deleteGroupImage = true
        avatarSelectionCell.setAvatar(image: nil)
    }

    func onImageSelected(image: UIImage) {
        changeGroupImage = image
        deleteGroupImage = false
        avatarSelectionCell.setAvatar(image: changeGroupImage)
    }

    func updateGroupContactIdsOnListSelection(_ members: Set<Int>) {
        contactIdsForGroup = members
        groupContactIds = Array(members)
        self.tableView.reloadData()
        checkDoneButton()
    }

    func removeGroupContactFromList(at indexPath: IndexPath) {
        let row = indexPath.row
        self.contactIdsForGroup.remove(self.groupContactIds[row])
        self.groupContactIds.remove(at: row)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            self.tableView.reloadData() // needed to update the "N members"-title, however do not interrupt the nice delete-animation
            self.checkDoneButton()
        }
        tableView.deleteRows(at: [indexPath], with: .fade)
        CATransaction.commit()
    }

    // MARK: - coordinator
    private func showGroupChat(chatId: Int) {
        if let chatlistViewController = navigationController?.viewControllers[0] as? ChatListViewController {
            let chatViewController = ChatViewController(dcContext: dcContext, chatId: chatId)
            chatlistViewController.backButtonUpdateableDataSource = chatViewController
            navigationController?.setViewControllers([chatlistViewController, chatViewController], animated: true)
        }
    }

    private func showPhotoPicker(delegate: MediaPickerDelegate) {
        mediaPicker?.showGallery(allowCropping: true)
    }

    private func showCamera(delegate: MediaPickerDelegate) {
        mediaPicker?.showCamera(allowCropping: true, supportedMediaTypes: .photo)
    }

    private func showAddMembers(preselectedMembers: Set<Int>) {
        let newGroupController = AddGroupMembersViewController(dcContext: dcContext, preselected: preselectedMembers, createMode: createMode)
        newGroupController.onMembersSelected = { [weak self] memberIds in
            guard let self else { return }
            var memberIds = memberIds
            if self.createMode != .createBroadcast {
                memberIds.insert(Int(DC_CONTACT_ID_SELF))
            }
            self.updateGroupContactIdsOnListSelection(memberIds)
        }
        navigationController?.pushViewController(newGroupController, animated: true)
    }
}

extension NewGroupController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

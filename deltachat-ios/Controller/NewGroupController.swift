import UIKit
import DcCore

class NewGroupController: UITableViewController, MediaPickerDelegate {
    var groupName: String = ""
    var groupChatId: Int = 0

    var doneButton: UIBarButtonItem!
    var contactIdsForGroup: Set<Int> // TODO: check if array is sufficient
    var groupContactIds: [Int]

    private var changeGroupImage: UIImage?
    private var deleteGroupImage: Bool = false

    let isVerifiedGroup: Bool
    let createBroadcast: Bool
    let dcContext: DcContext
    private var contactAddedObserver: NSObjectProtocol?

    enum DetailsRows {
        case name
        case avatar
    }
    private let detailsRows: [DetailsRows]

    enum InviteRows {
        case addMembers
        case showQrCode
    }
    private let inviteRows: [InviteRows]

    enum NewGroupSections {
        case details
        case invite
        case members
    }
    private let sections: [NewGroupSections]

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    lazy var groupNameCell: TextFieldCell = {
        let cell = TextFieldCell(description: String.localized(createBroadcast ? "name_desktop" : "group_name"), placeholder: String.localized("name_desktop"))
        cell.onTextFieldChange = self.updateGroupName
        cell.textField.autocorrectionType = UITextAutocorrectionType.no
        cell.textField.enablesReturnKeyAutomatically = true
        cell.textField.returnKeyType = .default
        cell.textFieldDelegate = self
        return cell
    }()

    lazy var avatarSelectionCell: AvatarSelectionCell = {
        let cell = AvatarSelectionCell(image: nil)
        cell.hintLabel.text = String.localized("group_avatar")
        cell.onAvatarTapped = onAvatarTapped
        return cell
    }()

    var qrInviteCodeCell: ActionCell?

    init(dcContext: DcContext, isVerified: Bool, createBroadcast: Bool) {
        self.isVerifiedGroup = isVerified
        self.createBroadcast = createBroadcast
        self.dcContext = dcContext
        self.sections = [.details, .invite, .members]
        if createBroadcast {
            self.detailsRows = [.name]
            self.inviteRows = [.addMembers]
            self.contactIdsForGroup = []
        } else {
            self.detailsRows = [.name, .avatar]
            self.inviteRows = [.addMembers, .showQrCode]
            self.contactIdsForGroup = [Int(DC_CONTACT_ID_SELF)]
        }
        self.groupContactIds = Array(contactIdsForGroup)
        super.init(style: .grouped)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if isVerifiedGroup {
            title = String.localized("menu_new_verified_group")
        } else if createBroadcast {
            title = String.localized("new_broadcast_list")
        } else {
            title = String.localized("menu_new_group")
        }
        doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonPressed))
        navigationItem.rightBarButtonItem = doneButton
        tableView.register(ContactCell.self, forCellReuseIdentifier: "contactCell")
        tableView.register(ActionCell.self, forCellReuseIdentifier: "actionCell")
        self.hideKeyboardOnTap()
        checkDoneButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        let nc = NotificationCenter.default
        contactAddedObserver = nc.addObserver(
            forName: dcNotificationChatModified,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self = self else { return }
            if let ui = notification.userInfo {
                if let chatId = ui["chat_id"] as? Int {
                    if self.groupChatId == 0 || chatId != self.groupChatId {
                        return
                    }
                    self.updateGroupContactIdsOnQRCodeInvite()
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        if let observer = self.contactAddedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func checkDoneButton() {
        let name = groupNameCell.textField.text ?? ""
        let nameOk = !name.isEmpty
        doneButton.isEnabled = nameOk && contactIdsForGroup.count >= 1
    }

    @objc func doneButtonPressed() {
        if createBroadcast {
            groupChatId = dcContext.createBroadcastList()
            _ = dcContext.setChatName(chatId: groupChatId, name: groupName)
        } else if groupChatId == 0 {
            groupChatId = dcContext.createGroupChat(verified: isVerifiedGroup, name: groupName)
        } else {
            _ = dcContext.setChatName(chatId: groupChatId, name: groupName)
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
            if inviteRows[row] == .addMembers {
                let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
                if let actionCell = cell as? ActionCell {
                    actionCell.actionTitle = String.localized(createBroadcast ? "add_recipients" : "group_add_members")
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
        case .members:
            let cell = tableView.dequeueReusableCell(withIdentifier: "contactCell", for: indexPath)
            if let contactCell = cell as? ContactCell {
                let contact = dcContext.getContact(id: groupContactIds[row])
                let displayName = contact.displayName
                contactCell.titleLabel.text = displayName
                contactCell.subtitleLabel.text = contact.email
                contactCell.avatar.setName(displayName)
                contactCell.avatar.setColor(contact.color)
                if let profileImage = contact.profileImage {
                    contactCell.avatar.setImage(profileImage)
                }
                contactCell.setVerified(isVerified: contact.isVerified)
                contactCell.selectionStyle = .none
            }
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if sections[section] == .details && isVerifiedGroup {
            return String.localized("verified_group_explain")
        } else if sections[section] == .invite && createBroadcast {
            return String.localized("chat_new_broadcast_hint")
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
            if createBroadcast {
                return String.localized(stringID: "n_recipients", count: contactIdsForGroup.count)
            } else {
                return String.localized(stringID: "n_members", count: contactIdsForGroup.count)
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
                showAddMembers(preselectedMembers: contactsWithoutSelf, isVerified: self.isVerifiedGroup)
            } else {
                self.groupChatId = dcContext.createGroupChat(verified: isVerifiedGroup, name: groupName)
                showQrCodeInvite(chatId: Int(self.groupChatId))
            }
        }
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let row = indexPath.row

        // swipe by delete
        if sections[indexPath.section] == .members, groupContactIds[indexPath.row] != DC_CONTACT_ID_SELF {
            let delete = UITableViewRowAction(style: .destructive, title: String.localized("remove_desktop")) { [weak self] _, indexPath in
                guard let self = self else { return }
                if self.groupChatId != 0,
                   self.dcContext.getChat(chatId: self.groupChatId).getContactIds(self.dcContext).contains(self.groupContactIds[row]) {
                    let success = self.dcContext.removeContactFromChat(chatId: self.groupChatId, contactId: self.groupContactIds[row])
                    if success {
                        self.removeGroupContactFromList(at: indexPath)
                    }
                } else {
                    self.removeGroupContactFromList(at: indexPath)
                }
            }
            delete.backgroundColor = UIColor.systemRed
            return [delete]
        } else {
            return nil
        }
    }

    private func updateGroupName(textView: UITextField) {
        let name = textView.text ?? ""
        groupName = name
        qrInviteCodeCell?.isUserInteractionEnabled = name.containsCharacters()
        qrInviteCodeCell?.actionColor = groupName.isEmpty ? DcColors.colorDisabled : UIColor.systemBlue
        checkDoneButton()
    }

    private func onAvatarTapped() {
        let alert = UIAlertController(title: String.localized("group_avatar"), message: nil, preferredStyle: .safeActionSheet)
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

    func updateGroupContactIdsOnQRCodeInvite() {
        for contactId in dcContext.getChat(chatId: groupChatId).getContactIds(dcContext) {
            contactIdsForGroup.insert(contactId)
        }
        groupContactIds = Array(contactIdsForGroup)
        self.tableView.reloadData()
        checkDoneButton()
    }

    func updateGroupContactIdsOnListSelection(_ members: Set<Int>) {
        if groupChatId != 0 {
            var members = members
            for contactId in dcContext.getChat(chatId: groupChatId).getContactIds(dcContext) {
                members.insert(contactId)
            }
        }
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
        if let chatlistViewController = navigationController?.viewControllers[0] {
            let chatViewController = ChatViewController(dcContext: dcContext, chatId: chatId)
            navigationController?.setViewControllers([chatlistViewController, chatViewController], animated: true)
        }
    }

    private func showPhotoPicker(delegate: MediaPickerDelegate) {
        mediaPicker?.showPhotoGallery()
    }

    private func showCamera(delegate: MediaPickerDelegate) {
        mediaPicker?.showCamera(allowCropping: true, supportedMediaTypes: .photo)
    }

    private func showQrCodeInvite(chatId: Int) {
        var hint = ""
        let dcChat = dcContext.getChat(chatId: chatId)
        if !dcChat.name.isEmpty {
            hint = String.localizedStringWithFormat(String.localized("qrshow_join_group_hint"), dcChat.name)
        }
        let qrInviteCodeController = QrViewController(dcContext: dcContext, chatId: chatId, qrCodeHint: hint)
        qrInviteCodeController.onDismissed = { [weak self] in
            self?.updateGroupContactIdsOnQRCodeInvite()
        }
        navigationController?.pushViewController(qrInviteCodeController, animated: true)
    }

    private func showAddMembers(preselectedMembers: Set<Int>, isVerified: Bool) {
        let newGroupController = AddGroupMembersViewController(dcContext: dcContext,
                                                               preselected: preselectedMembers,
                                                               isVerified: isVerified,
                                                               isBroadcast: createBroadcast)
        newGroupController.onMembersSelected = { [weak self] (memberIds: Set<Int>) -> Void in
            guard let self = self else { return }
            var memberIds = memberIds
            if !self.createBroadcast {
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

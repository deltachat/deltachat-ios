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
    let dcContext: DcContext
    private var contactAddedObserver: NSObjectProtocol?

    private let sectionGroupDetails = 0
    private let sectionGroupDetailsRowName = 0
    private let sectionGroupDetailsRowAvatar = 1
    private let countSectionGroupDetails = 2
    private let sectionInvite = 1
    private let sectionInviteRowAddMembers = 0
    private let sectionInviteRowShowQrCode = 1
    private lazy var countSectionInvite: Int = 2
    private let sectionGroupMembers = 2

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    lazy var groupNameCell: TextFieldCell = {
        let cell = TextFieldCell(description: String.localized("group_name"), placeholder: String.localized("group_name"))
        cell.onTextFieldChange = self.updateGroupName
        cell.textField.autocorrectionType = UITextAutocorrectionType.no
        cell.textField.enablesReturnKeyAutomatically = true
        cell.textField.returnKeyType = .continue
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
        doneButton.isEnabled = false
        tableView.register(ContactCell.self, forCellReuseIdentifier: "contactCell")
        tableView.register(ActionCell.self, forCellReuseIdentifier: "actionCell")
        self.hideKeyboardOnTap()
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


    @objc func doneButtonPressed() {
        if groupChatId == 0 {
            groupChatId = dcContext.createGroupChat(verified: isVerifiedGroup, name: groupName)
        } else {
            _ = dcContext.setChatName(chatId: groupChatId, name: groupName)
        }

        for contactId in contactIdsForGroup {
            let success = dcContext.addContactToChat(chatId: groupChatId, contactId: contactId)

            if let groupImage = changeGroupImage {
                AvatarHelper.saveChatAvatar(dcContext: dcContext, image: groupImage, for: groupChatId)
            } else if deleteGroupImage {
                AvatarHelper.saveChatAvatar(dcContext: dcContext, image: nil, for: groupChatId)
            }

            if success {
                logger.info("successfully added \(contactId) to group \(groupName)")
            } else {
                logger.error("failed to add \(contactId) to group \(groupName)")
            }
        }

        showGroupChat(chatId: Int(groupChatId))
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
        if section == sectionGroupDetails && isVerifiedGroup {
            return String.localized("verified_group_explain")
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = indexPath.section
        switch section {
        case sectionGroupDetails, sectionInvite:
            return UITableView.automaticDimension
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
                showAddMembers(preselectedMembers: contactsWithoutSelf, isVerified: self.isVerifiedGroup)
            } else {
                self.groupChatId = dcContext.createGroupChat(verified: isVerifiedGroup, name: groupName)
                showQrCodeInvite(chatId: Int(self.groupChatId))
            }
        }
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let section = indexPath.section
        let row = indexPath.row

        //swipe by delete
        if section == sectionGroupMembers, groupContactIds[row] != DC_CONTACT_ID_SELF {
            let delete = UITableViewRowAction(style: .destructive, title: String.localized("remove_desktop")) { [weak self] _, indexPath in
                guard let self = self else { return }
                if self.groupChatId != 0,
                    self.dcContext.getChat(chatId: self.groupChatId).contactIds.contains(self.groupContactIds[row]) {
                    let success = self.dcContext.removeContactFromChat(chatId: self.groupChatId, contactId: self.groupContactIds[row])
                    if success {
                        self.removeGroupContactFromList(at: indexPath)
                    }
                } else {
                    self.removeGroupContactFromList(at: indexPath)
                }
            }
            delete.backgroundColor = UIColor.red
            return [delete]
        } else {
            return nil
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
        for contactId in dcContext.getChat(chatId: groupChatId).contactIds {
            contactIdsForGroup.insert(contactId)
        }
        groupContactIds = Array(contactIdsForGroup)
        self.tableView.reloadData()
    }

    func updateGroupContactIdsOnListSelection(_ members: Set<Int>) {
        if groupChatId != 0 {
            var members = members
            for contactId in dcContext.getChat(chatId: groupChatId).contactIds {
                members.insert(contactId)
            }
        }
        contactIdsForGroup = members
        groupContactIds = Array(members)
        self.tableView.reloadData()
    }

    func removeGroupContactFromList(at indexPath: IndexPath) {
        let row = indexPath.row
        self.contactIdsForGroup.remove(self.groupContactIds[row])
        self.groupContactIds.remove(at: row)
        tableView.deleteRows(at: [indexPath], with: .fade)
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
        let newGroupController = AddGroupMembersViewController(preselected: preselectedMembers,
                                                                  isVerified: isVerified)
        newGroupController.onMembersSelected = { [weak self] (memberIds: Set<Int>) -> Void in
            guard let self = self else { return }
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

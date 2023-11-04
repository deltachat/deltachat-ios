import UIKit
import DcCore

class EditGroupViewController: UITableViewController, MediaPickerDelegate {
    private let dcContext: DcContext
    private let chat: DcChat

    private var changeGroupImage: UIImage?
    private var deleteGroupImage: Bool = false
    private var useGroupWording: Bool

    enum EditRows {
         case name
         case avatar
    }
    private let editRows: [EditRows]

    var avatarSelectionCell: AvatarSelectionCell

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(dcContext: dcContext, navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    lazy var groupNameCell: TextFieldCell = {
        let cell = TextFieldCell(description: String.localized(useGroupWording ? "group_name" : "name_desktop"), placeholder: self.chat.name)
        cell.setText(text: self.chat.name)
        cell.onTextFieldChange = self.groupNameEdited(_:)
        return cell
    }()

    lazy var doneButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveContactButtonPressed))
        button.isEnabled = false
        return button
    }()

    lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        return button
    }()

    init(dcContext: DcContext, chat: DcChat) {
        self.dcContext = dcContext
        self.chat = chat
        self.avatarSelectionCell = AvatarSelectionCell(image: chat.profileImage)
        self.useGroupWording = !chat.isBroadcast && !chat.isMailinglist
        if chat.isBroadcast {
            self.editRows = [.name]
        } else {
            self.editRows = [.name, .avatar]
        }
        super.init(style: .grouped)
        self.avatarSelectionCell.hintLabel.text = String.localized(useGroupWording ? "group_avatar" : "image")
        self.avatarSelectionCell.onAvatarTapped = onAvatarTapped
        title = String.localized(useGroupWording ? "menu_edit_group" : "global_menu_edit_desktop")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = doneButton
        navigationItem.leftBarButtonItem = cancelButton
        tableView.rowHeight = UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if editRows[indexPath.row] == .avatar {
            return avatarSelectionCell
        } else {
            return groupNameCell
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return editRows.count
    }
    
    @objc func saveContactButtonPressed() {
        let newName = groupNameCell.getText()
        if let groupImage = changeGroupImage {
            AvatarHelper.saveChatAvatar(dcContext: dcContext, image: groupImage, for: chat.id)
        } else if deleteGroupImage {
            AvatarHelper.saveChatAvatar(dcContext: dcContext, image: nil, for: chat.id)
        }
        _ = dcContext.setChatName(chatId: chat.id, name: newName ?? "")
        navigationController?.popViewController(animated: true)
    }

    @objc func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

    private func groupNameEdited(_ textField: UITextField) {
        doneButton.isEnabled = true
    }

    private func onAvatarTapped() {
        let alert = UIAlertController(title: String.localized(useGroupWording ? "group_avatar" : "image"), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(PhotoPickerAlertAction(title: String.localized("camera"), style: .default, handler: cameraButtonPressed(_:)))
            alert.addAction(PhotoPickerAlertAction(title: String.localized("gallery"), style: .default, handler: galleryButtonPressed(_:)))
            if avatarSelectionCell.isAvatarSet() {
                alert.addAction(UIAlertAction(title: String.localized("delete"), style: .destructive, handler: deleteGroupAvatarPressed(_:)))
            }
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func galleryButtonPressed(_ action: UIAlertAction) {
        mediaPicker?.showPhotoGallery()
    }

    private func cameraButtonPressed(_ action: UIAlertAction) {
        mediaPicker?.showCamera(allowCropping: true, supportedMediaTypes: .photo)
    }

    private func deleteGroupAvatarPressed(_ action: UIAlertAction) {
        changeGroupImage = nil
        deleteGroupImage = true
        doneButton.isEnabled = true
        avatarSelectionCell.setAvatar(image: nil)
    }

    func onImageSelected(image: UIImage) {
        changeGroupImage = image
        deleteGroupImage = false
        doneButton.isEnabled = true
        avatarSelectionCell.setAvatar(image: changeGroupImage)
    }
}

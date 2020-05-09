import UIKit
import DcCore

class EditGroupViewController: UITableViewController, MediaPickerDelegate {
    private let dcContext: DcContext
    private let chat: DcChat
    private var groupImage: UIImage?

    private let rowAvatar = 0
    private let rowGroupName = 1

    var avatarSelectionCell: AvatarSelectionCell

    private lazy var mediaPicker: MediaPicker? = {
        if let navigationController = navigationController {
            return MediaPicker(navigationController: navigationController)
        } else {
            return nil
        }
    }()

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

    init(dcContext: DcContext, chat: DcChat) {
        self.dcContext = dcContext
        self.chat = chat
        self.avatarSelectionCell = AvatarSelectionCell(chat: chat)
        super.init(style: .grouped)
        self.avatarSelectionCell.hintLabel.text = String.localized("group_avatar")
        self.avatarSelectionCell.onAvatarTapped = onAvatarTapped
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
            return AvatarSelectionCell.cellHeight
        }
        return Constants.defaultCellHeight
    }
    
    @objc func saveContactButtonPressed() {
        let newName = groupNameCell.getText()
        if let groupImage = groupImage {
            AvatarHelper.saveChatAvatar(dcContext: dcContext, image: groupImage, for: Int(chat.id))
        }
        _ = dcContext.setChatName(chatId: chat.id, name: newName ?? "")
        navigateBack()
    }

    @objc func cancelButtonPressed() {
        navigateBack()
    }

    private func groupNameEdited(_ textField: UITextField) {
        avatarSelectionCell.onInitialsChanged(text: textField.text)
        doneButton.isEnabled = true
    }

    private func onAvatarTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .safeActionSheet)
            let photoAction = PhotoPickerAlertAction(title: String.localized("gallery"), style: .default, handler: galleryButtonPressed(_:))
            let videoAction = PhotoPickerAlertAction(title: String.localized("camera"), style: .default, handler: cameraButtonPressed(_:))
            alert.addAction(photoAction)
            alert.addAction(videoAction)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func galleryButtonPressed(_ action: UIAlertAction) {
        mediaPicker?.showPhotoGallery(delegate: self)
    }

    private func cameraButtonPressed(_ action: UIAlertAction) {
        mediaPicker?.showCamera(delegate: self)
    }

    func onImageSelected(image: UIImage) {
        groupImage = image
        doneButton.isEnabled = true

        avatarSelectionCell = AvatarSelectionCell(context: nil, with: groupImage)
        avatarSelectionCell.hintLabel.text = String.localized("group_avatar")
        avatarSelectionCell.onAvatarTapped = onAvatarTapped

        self.tableView.beginUpdates()
        let indexPath = IndexPath(row: rowAvatar, section: 0)
        self.tableView.reloadRows(at: [indexPath], with: UITableView.RowAnimation.none)
        self.tableView.endUpdates()
    }

    // MARK: - coordinator
    func navigateBack() {
        navigationController?.popViewController(animated: true)
    }
}

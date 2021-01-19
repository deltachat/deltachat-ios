import UIKit
import DcCore

class ProfileInfoViewController: UITableViewController {
    var onClose: VoidFunction?
    private let dcContext: DcContext
    private var displayName: String?

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    private lazy var doneButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(
            title: String.localized("done"),
            style: .done,
            target: self,
            action: #selector(doneButtonPressed(_:))
        )
    }()

    private lazy var avatarCell: AvatarSelectionCell = {
        let cell = AvatarSelectionCell(image: dcContext.getSelfAvatarImage())
        cell.onAvatarTapped = avatarTapped
        return cell
    }()

    private lazy var nameCell: TextFieldCell = {
        let cell =  TextFieldCell.makeNameCell(delegate: self)
        cell.placeholder = String.localized("pref_your_name")
        cell.setText(text: dcContext.displayname)
        cell.onTextFieldChange = {[weak self] textField in
            self?.displayName = textField.text
        }
        cell.textField.returnKeyType = .default
        return cell
    }()

    private lazy var cells = [nameCell, avatarCell]

    init(context: DcContext) {
        self.dcContext = context
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("pref_profile_info_headline")
        navigationItem.rightBarButtonItem = doneButtonItem
        tableView.rowHeight = UITableView.automaticDimension
    }

    // MARK: - tableviewDelegate
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let email = dcContext.addr ?? ""
        let footerTitle = String.localizedStringWithFormat(
            String.localized("qraccount_success_enter_name"), email
        )
        return footerTitle
    }

    // MARK: - updates
    private func updateAvatarCell() {
        let avatarImage = dcContext.getSelfAvatarImage()
        avatarCell.setAvatar(image: avatarImage)
    }

    // MARK: - actions
    private func avatarTapped() {
        let sender = avatarCell.badge
        let alert = UIAlertController(
            title: String.localized("pref_profile_photo"),
            message: nil,
            preferredStyle: .actionSheet
        )
        let galleryAction = PhotoPickerAlertAction(
            title: String.localized("gallery"),
            style: .default,
            handler: galleryButtonPressed(_:)
        )
        let cameraAction = PhotoPickerAlertAction(
            title: String.localized("camera"),
            style: .default,
            handler: cameraButtonPressed(_:)
        )
        alert.addAction(cameraAction)
        alert.addAction(galleryAction)

        if dcContext.getSelfAvatarImage() != nil {
            let deleteAction = UIAlertAction(
                title: String.localized("delete"),
                style: .destructive,
                handler: deleteProfileIconPressed(_:)
            )
            alert.addAction(deleteAction)
        }

        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = self.avatarCell
            popoverController.sourceRect = CGRect(
                x: sender.frame.minX - 10,
                y: sender.frame.minY,
                width: sender.frame.width,
                height: sender.frame.height
            )
         }
        self.present(alert, animated: true, completion: nil)
    }

    @objc private func doneButtonPressed(_ sender: UIBarButtonItem) {
        dcContext.displayname = displayName
        onClose?()
    }

    private func galleryButtonPressed(_ action: UIAlertAction) {
        mediaPicker?.showPhotoGallery()
    }

    private func cameraButtonPressed(_ action: UIAlertAction) {
        mediaPicker?.showCamera(allowCropping: true, supportedMediaTypes: .photo)
    }

    private func deleteProfileIconPressed(_ action: UIAlertAction) {
        dcContext.selfavatar = nil
        updateAvatarCell()
    }
}

extension ProfileInfoViewController: MediaPickerDelegate {
    func onImageSelected(image: UIImage) {
        AvatarHelper.saveSelfAvatarImage(dcContext: dcContext, image: image)
        updateAvatarCell()
    }
}

extension ProfileInfoViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

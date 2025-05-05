import UIKit
import DcCore

class SelfProfileViewController: UITableViewController, MediaPickerDelegate {

    private struct SectionConfigs {
        let headerTitle: String?
        let footerTitle: String?
        let cells: [UITableViewCell]
    }

    private let dcContext: DcContext

    lazy var doneButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonPressed))
    }()

    lazy var cancelButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
    }()

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(dcContext: dcContext, navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    private lazy var statusCell: MultilineTextFieldCell = {
        let cell = MultilineTextFieldCell(description: String.localized("pref_default_status_label"),
                                          multilineText: dcContext.selfstatus,
                                          placeholder: String.localized("pref_default_status_label"))
        return cell
    }()

    private lazy var avatarSelectionCell: AvatarSelectionCell = {
        return AvatarSelectionCell(image: dcContext.getSelfAvatarImage())
    }()
    private var changeAvatar: UIImage?
    private var deleteAvatar: Bool = false

    private lazy var nameCell: TextFieldCell = {
        let cell = TextFieldCell(description: String.localized("pref_your_name"), placeholder: String.localized("please_enter_name"))
        cell.setText(text: dcContext.displayname)
        cell.textFieldDelegate = self
        cell.textField.returnKeyType = .default
        return cell
    }()

    private lazy var sections: [SectionConfigs] = {
        let nameSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: String.localized("pref_who_can_see_profile_explain"),
            cells: [nameCell, avatarSelectionCell, statusCell]
        )
        return [nameSection]
    }()

    init(dcAccounts: DcAccounts) {
        self.dcContext = dcAccounts.getSelected()
        super.init(style: .insetGrouped)
        hidesBottomBarWhenPushed = true

        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: UITextField.textDidChangeNotification, object: nameCell.textField)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("pref_profile_info_headline")
        avatarSelectionCell.onAvatarTapped = { [weak self] in
            self?.onAvatarTapped()
        }
        tableView.rowHeight = UITableView.automaticDimension
        navigationItem.rightBarButtonItem = doneButton
        navigationItem.leftBarButtonItem = cancelButton
        validateFields()
    }

    func validateFields() {
        doneButton.isEnabled = !(nameCell.textField.text?.isEmpty ?? true)
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return sections[indexPath.section].cells[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerTitle
    }

    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
    }

    // MARK: - Notifications
    @objc func textDidChange(notification: Notification) {
        validateFields()
    }

    // MARK: - actions
    @objc func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

    @objc func doneButtonPressed() {
        dcContext.selfstatus = statusCell.getText()
        dcContext.displayname = nameCell.getText()
        if let changeAvatar {
            AvatarHelper.saveSelfAvatarImage(dcContext: dcContext, image: changeAvatar)
        } else if deleteAvatar {
            dcContext.selfavatar = nil
        }
        navigationController?.popViewController(animated: true)
    }

    private func enlargeAvatarPressed(_ action: UIAlertAction) {
        // temporarily save to file as PreviewController uses QLPreviewItem which does not accept UIImage
        guard let image = avatarSelectionCell.badge.getImage() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("preview.png")
        guard let imageData = image.pngData() else { return }
        guard (try? imageData.write(to: url)) != nil else { return }

        let previewController = PreviewController(dcContext: dcContext, type: .single(url))
        previewController.customTitle = String.localized("pref_profile_photo")
        navigationController?.pushViewController(previewController, animated: true)
    }

    private func galleryButtonPressed(_ action: UIAlertAction) {
        mediaPicker?.showGallery(allowCropping: true)
    }

    private func cameraButtonPressed(_ action: UIAlertAction) {
        mediaPicker?.showCamera(allowCropping: true, supportedMediaTypes: .photo)
    }

    private func deleteProfileIconPressed(_ action: UIAlertAction) {
        changeAvatar = nil
        deleteAvatar = true
        avatarSelectionCell.setAvatar(image: nil)
    }

    private func onAvatarTapped() {
        let alert = UIAlertController(title: String.localized("pref_profile_photo"), message: nil, preferredStyle: .safeActionSheet)
        if avatarSelectionCell.isAvatarSet() {
            alert.addAction(UIAlertAction(title: String.localized("global_menu_view_desktop"), style: .default, handler: enlargeAvatarPressed(_:)))
        }
        alert.addAction(PhotoPickerAlertAction(title: String.localized("camera"), style: .default, handler: cameraButtonPressed(_:)))
        alert.addAction(PhotoPickerAlertAction(title: String.localized("gallery"), style: .default, handler: galleryButtonPressed(_:)))
        if avatarSelectionCell.isAvatarSet() {
            alert.addAction(UIAlertAction(title: String.localized("delete"), style: .destructive, handler: deleteProfileIconPressed(_:)))
        }
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))

        self.present(alert, animated: true, completion: nil)
    }

    func onImageSelected(image: UIImage) {
        changeAvatar = image
        deleteAvatar = false
        avatarSelectionCell.setAvatar(image: image)
    }
}


extension SelfProfileViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

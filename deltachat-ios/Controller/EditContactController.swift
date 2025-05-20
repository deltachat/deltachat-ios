import UIKit
import DcCore

class EditContactController: UITableViewController {
    let dcContext: DcContext
    let dcContact: DcContact
    let authNameOrAddr: String
    let nameCell = TextFieldCell.makeNameCell()
    let cells: [UITableViewCell]

    init(dcContext: DcContext, contactIdForUpdate: Int) {
        self.dcContext = dcContext
        dcContact = dcContext.getContact(id: contactIdForUpdate)
        authNameOrAddr = dcContact.authName.isEmpty ? dcContact.email : dcContact.authName
        cells = [nameCell]
        super.init(style: .insetGrouped)

        nameCell.textFieldDelegate = self
        nameCell.textField.text = dcContact.editedName
        nameCell.textField.enablesReturnKeyAutomatically = false
        nameCell.textField.returnKeyType = .done
        nameCell.useFullWidth()
        nameCell.placeholder = String.localizedStringWithFormat(String.localized("edit_name_placeholder"), authNameOrAddr)

        title = String.localized("menu_edit_name")
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveButtonPressed))
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_: Bool) {
        nameCell.textField.becomeFirstResponder()
    }

    @objc func saveButtonPressed() {
        dcContext.changeContactName(contactId: dcContact.id, name: nameCell.textField.text ?? "")
        navigationController?.popViewController(animated: true)
    }

    @objc func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return cells.count
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return String.localizedStringWithFormat(String.localized("edit_name_explain"), authNameOrAddr)
    }
}

extension EditContactController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        saveButtonPressed()
        return true
    }
}

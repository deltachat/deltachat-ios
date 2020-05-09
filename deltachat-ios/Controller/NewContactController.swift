import UIKit
import DcCore

class NewContactController: UITableViewController {

    let dcContext: DcContext
    var openChatOnSave = true

    let emailCell = TextFieldCell.makeEmailCell()
    let nameCell = TextFieldCell.makeNameCell()
    var doneButton: UIBarButtonItem?
    var cancelButton: UIBarButtonItem?

    func contactIsValid() -> Bool {
        return Utils.isValid(email: model.email)
    }

    var model: (name: String, email: String) = ("", "") {
        didSet {
            if contactIsValid() {
                doneButton?.isEnabled = true
            } else {
                doneButton?.isEnabled = false
            }
        }
    }

    let cells: [UITableViewCell]

    // for creating a new contact
    init(dcContext: DcContext) {
        self.dcContext = dcContext
        cells = [emailCell, nameCell]
        super.init(style: .grouped)
        emailCell.textField.delegate = self
        nameCell.textField.delegate = self

        // always show return key with name field, because
        // name is optional
        nameCell.textField.enablesReturnKeyAutomatically = false
        emailCell.textField.returnKeyType = .next
        nameCell.textField.returnKeyType = .done

        title = String.localized("menu_new_contact")
        doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(saveContactButtonPressed))
        doneButton?.isEnabled = false
        navigationItem.rightBarButtonItem = doneButton

        cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        navigationItem.leftBarButtonItem = cancelButton

        emailCell.textField.addTarget(self, action: #selector(NewContactController.emailTextChanged), for: UIControl.Event.editingChanged)
        nameCell.textField.addTarget(self, action: #selector(NewContactController.nameTextChanged), for: UIControl.Event.editingChanged)
    }

    override func viewDidAppear(_: Bool) {
        if emailCell.textField.isEnabled {
            emailCell.textField.becomeFirstResponder()
        } else {
            nameCell.textField.becomeFirstResponder()
        }
    }

    @objc func emailTextChanged() {
        let emailText = emailCell.textField.text ?? ""
        model.email = emailText
    }

    @objc func nameTextChanged() {
        let nameText = nameCell.textField.text ?? ""
        model.name = nameText
    }

    @objc func saveContactButtonPressed() {
        let contactId = dcContext.createContact(name: model.name, email: model.email)
        let chatId = dcContext.createChatByContactId(contactId: contactId)
        if openChatOnSave {
            showChat(chatId: chatId)
        } else {
            navigateBack()
        }
    }

    @objc func cancelButtonPressed() {
        navigateBack()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return cells.count
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row

        return cells[row]
    }

    // MARK: - coordinator
    func navigateBack() {
        navigationController?.popViewController(animated: true)
    }

    func showChat(chatId: Int) {
        let chatViewController = ChatViewController(dcContext: dcContext, chatId: chatId)
        navigationController?.popToRootViewController(animated: false)
        navigationController?.pushViewController(chatViewController, animated: true)
    }
}

extension NewContactController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailCell.textField {
            // only switch to next line if email is valid
            if contactIsValid() {
                nameCell.textField.becomeFirstResponder()
            }
        } else if textField == nameCell.textField {
            if contactIsValid() {
                saveContactButtonPressed()
            }
        }
        return true
    }
}

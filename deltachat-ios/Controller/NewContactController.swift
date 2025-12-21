import UIKit
import DcCore

class NewContactController: UITableViewController {

    let dcContext: DcContext
    let createChatOnSave: Bool
    var prefilledSeachResult: String?

    let emailCell = TextFieldCell.makeEmailCell()
    let nameCell = TextFieldCell.makeNameCell()
    var doneButton: UIBarButtonItem?
    var cancelButton: UIBarButtonItem?

    var onContactSaved: ((Int) -> Void)?

    func contactIsValid() -> Bool {
        return DcContext.mayBeValidAddr(email: model.email)
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
    init(dcContext: DcContext, createChatOnSave: Bool = true, searchResult: String? = nil) {
        self.dcContext = dcContext
        self.createChatOnSave = createChatOnSave
        cells = [emailCell, nameCell]
        prefilledSeachResult = searchResult
        super.init(style: .insetGrouped)
        emailCell.textFieldDelegate = self
        nameCell.textFieldDelegate = self

        // always show return key with name field, because
        // name is optional
        nameCell.textField.enablesReturnKeyAutomatically = false
        emailCell.textField.returnKeyType = .next
        nameCell.textField.returnKeyType = .done

        title = String.localized("menu_new_classic_contact")
        doneButton = UIBarButtonItem(title: String.localized("create"), style: .done, target: self, action: #selector(saveContactButtonPressed))
        doneButton?.isEnabled = false
        navigationItem.rightBarButtonItem = doneButton

        cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        navigationItem.leftBarButtonItem = cancelButton

        emailCell.textField.addTarget(self, action: #selector(NewContactController.emailTextChanged), for: UIControl.Event.editingChanged)
        nameCell.textField.addTarget(self, action: #selector(NewContactController.nameTextChanged), for: UIControl.Event.editingChanged)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let searchResult = prefilledSeachResult, searchResult.contains("@") {
            emailCell.textField.insertText(searchResult)
        }
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
        if let onContactSaved = self.onContactSaved {
            onContactSaved(contactId)
        }
        navigationController?.popViewController(animated: true)
        if createChatOnSave {
            let chatId = dcContext.createChatByContactId(contactId: contactId)
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            appDelegate.appCoordinator.showChat(chatId: chatId, clearViewControllerStack: true)
        }
    }

    @objc func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
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

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return String.localized("new_classic_contact_explain")
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
            } else {
                emailCell.textField.becomeFirstResponder()
            }
        }
        return true
    }
}

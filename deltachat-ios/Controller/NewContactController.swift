import UIKit

class NewContactController: UITableViewController {

    weak var coordinator: EditContactCoordinatorProtocol?

    let emailCell = TextFieldCell.makeEmailCell()
    let nameCell = TextFieldCell.makeNameCell()
    var doneButton: UIBarButtonItem?
    var cancelButton: UIBarButtonItem?

    func contactIsValid() -> Bool {
        return Utils.isValid(model.email)
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
    init() {
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

    override func viewWillAppear(_: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.prefersLargeTitles = false
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
        let contactId = dc_create_contact(mailboxPointer, model.name, model.email)
        let chatId = Int(dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId)))
        askToChatWith(contactId: Int(contactId), chatId: chatId)
    }

    private func askToChatWith(contactId: Int, chatId: Int) {
        let dcContact = DcContact(id: contactId)
        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), dcContact.nameNAddr),
                                      message: nil,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
            self.dismiss(animated: true, completion: nil)
            self.coordinator?.showChat(chatId: chatId)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }

    @objc func cancelButtonPressed() {
        coordinator?.navigateBack()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.prefersLargeTitles = true
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return cells.count
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row

        return cells[row]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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

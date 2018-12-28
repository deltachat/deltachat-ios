//
//  NewContactController.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 17.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class NewContactController: UITableViewController {
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

    // for editing existing contacts (only
    // the name may be edited, therefore disable
    // the email field)
    convenience init(contactIdForUpdate: Int) {
        self.init()
        title = "Edit Contact"

        let contact = MRContact(id: contactIdForUpdate)
        nameCell.textField.text = contact.name
        emailCell.textField.text = contact.email
        emailCell.textField.isEnabled = false
        emailCell.contentView.alpha = 0.3

        model.name = contact.name
        model.email = contact.email

        if contactIsValid() {
            doneButton?.isEnabled = true
        }
    }

    override func viewWillAppear(_: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

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

        title = "New Contact"
        doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(NewContactController.saveContactButtonPressed))
        doneButton?.isEnabled = false
        navigationItem.rightBarButtonItem = doneButton

        cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(NewContactController.cancelButtonPressed))
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
        dc_create_contact(mailboxPointer, model.name, model.email)
        navigationController?.popViewController(animated: true)
    }

    @objc func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
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

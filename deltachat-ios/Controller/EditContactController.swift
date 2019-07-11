import UIKit

class EditContactController: NewContactController {

    // for editing existing contacts (only
    // the name may be edited, therefore disable
    // the email field)
    init(contactIdForUpdate: Int) {
        super.init()
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

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc override func saveContactButtonPressed() {
        dc_create_contact(mailboxPointer, model.name, model.email)
        coordinator?.navigateBack()
    }

}

import UIKit
import DcCore

class EditContactController: NewContactController {

    init(dcContext: DcContext, contactIdForUpdate: Int) {
        super.init(dcContext: dcContext)
        title = String.localized("edit_contact")

        let contact = dcContext.getContact(id: contactIdForUpdate)

        nameCell.textField.text = contact.editedName
        if !contact.authName.isEmpty { // else show string "Name" as set by super.init()
            nameCell.placeholder = contact.authName
        }
        emailCell.textField.text = contact.email
        emailCell.textField.isEnabled = false // only contact name can be edited
        emailCell.contentView.alpha = 0.3

        model.name = contact.editedName
        model.email = contact.email

        doneButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveContactButtonPressed))
        doneButton?.isEnabled = contactIsValid()
        navigationItem.rightBarButtonItem = doneButton
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc override func saveContactButtonPressed() {
        _ = dcContext.createContact(name: model.name, email: model.email)
        navigationController?.popViewController(animated: true)
    }

}

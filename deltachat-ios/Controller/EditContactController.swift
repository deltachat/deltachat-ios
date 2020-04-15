import UIKit
import DcCore

class EditContactController: NewContactController {

    // for editing existing contacts (only
    // the name may be edited, therefore disable
    // the email field)
    init(dcContext: DcContext, contactIdForUpdate: Int) {
        super.init(dcContext: dcContext)
        title = String.localized("edit_contact")

        let contact = DcContact(id: contactIdForUpdate)
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
        _ = dcContext.createContact(name: model.name, email: model.email)
        coordinator?.navigateBack()
    }

}

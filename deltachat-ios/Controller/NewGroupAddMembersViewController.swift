import UIKit
import DcCore

class NewGroupAddMembersViewController: GroupMembersViewController {
    var onMembersSelected: ((Set<Int>) -> Void)?
    let isVerifiedGroup: Bool

    private lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        return button
    }()

   lazy var doneButton: UIBarButtonItem = {
       let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonPressed))
       return button
   }()

    init(preselected: Set<Int>, isVerified: Bool) {
        isVerifiedGroup = isVerified
        super.init()
        selectedContactIds = preselected
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("group_add_members")
        navigationItem.rightBarButtonItem = doneButton
        navigationItem.leftBarButtonItem = cancelButton
        contactIds = isVerifiedGroup ?
            dcContext.getContacts(flags: DC_GCL_VERIFIED_ONLY) :
            dcContext.getContacts(flags: 0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @objc func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

    @objc func doneButtonPressed() {
        if let onMembersSelected = onMembersSelected {
            selectedContactIds.insert(Int(DC_CONTACT_ID_SELF))
            onMembersSelected(selectedContactIds)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

}

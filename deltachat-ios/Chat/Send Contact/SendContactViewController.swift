import UIKit
import DcCore

protocol SendContactViewControllerDelegate: AnyObject {

}

class SendContactViewController: UIViewController {

    private let context: DcContext
    private let contactIds: [Int]

    var delegate: SendContactViewControllerDelegate?

    init(dcContext: DcContext) {
        // tableView with a list of all contacts I have

        context = dcContext
        contactIds = dcContext.getContacts(flags: DC_GCL_ADD_SELF)

        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = .green
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

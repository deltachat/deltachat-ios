import UIKit
import DcCore

class MessageInfoViewController: UIViewController {
    var dcContext: DcContext
    var message: DcMsg
    private static let reuseIdentifier = "MessageInfoCell"

    init(dcContext: DcContext, message: DcMsg) {
        self.dcContext = dcContext
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("menu_message_details")

        let textView = UITextView(frame: view.frame)
        textView.text = dcContext.getMsgInfo(msgId: message.id)
        textView.isEditable = false
        textView.font = .preferredFont(forTextStyle: .body)
        view.addSubview(textView)
        textView.fillSuperview()
    }
}

import UIKit

class MailboxViewController: ChatViewController {
    override init(dcContext: DcContext, chatId: Int, title: String? = nil) {
        super.init(dcContext: dcContext, chatId: chatId, title: title)
        hidesBottomBarWhenPushed = false
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
}

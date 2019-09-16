import UIKit

class MailboxViewController: ChatViewController {

    override init(dcContext: DcContext, chatId: Int) {
        super.init(dcContext: dcContext, chatId: chatId)
        hidesBottomBarWhenPushed = false
        disableWriting = true
        showCustomNavBar = false
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = String.localized("menu_deaddrop")

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NavBarUtils.setBigTitle(navigationController: navigationController)
    }

}

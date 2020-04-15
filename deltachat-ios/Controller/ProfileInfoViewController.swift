import UIKit
import DcCore

class ProfileInfoViewController: UIViewController {

    private let dcContext: DcContext

    init(context: DcContext) {
        self.dcContext = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("pref_profile_info_headline")
    }

}

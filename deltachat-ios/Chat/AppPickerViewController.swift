import UIKit
import WebKit

protocol AppPickerViewControllerDelegate: AnyObject {

}

class AppPickerViewController: UIViewController {
    // Web view
    // Context
    weak var delegate: AppPickerViewControllerDelegate?

    init() {
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .systemGroupedBackground
        title = String.localized("webxdc_apps")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

extension AppPickerViewController: WKNavigationDelegate {
    // intercept download, store in core and call delegate
}

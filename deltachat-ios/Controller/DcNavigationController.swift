import UIKit
import Reachability

final class DcNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 11.0, *) {
            // preferred height of navigation bar title is configured in ViewControllers
        } else {
            //navigationBar.setBackgroundImage(UIImage(), for: .default)
        }
        //navigationBar.backgroundColor = .white
    }

}

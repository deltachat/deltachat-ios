import UIKit

extension UIApplication {
    var orientation: UIInterfaceOrientation? {
        UIApplication.shared.delegate?.window??.windowScene?.interfaceOrientation
    }
}

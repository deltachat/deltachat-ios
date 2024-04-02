import UIKit

class LegacyMenuItem: UIMenuItem {
    var indexPath: IndexPath?

    convenience init(title: String, action: Selector, indexPath: IndexPath?) {
        self.init(title: title, action: action)

        self.indexPath = indexPath
    }
}

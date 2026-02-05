import UIKit

extension NSLayoutConstraint {
    static func activate(_ constraints: [NSLayoutConstraint], withPriority priority: UILayoutPriority) {
        constraints.forEach { $0.priority = priority }
        activate(constraints)
    }
}

import UIKit

extension NSLayoutConstraint {
    func withPriority(_ priority: UILayoutPriority) -> Self {
        self.priority = priority
        return self
    }

    static func activate(_ constraints: [NSLayoutConstraint], withPriority priority: UILayoutPriority) {
        activate(constraints.map { $0.withPriority(priority) })
    }
}

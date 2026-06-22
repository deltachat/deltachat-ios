import UIKit

/// Protocol for reusable table view cells, defining a static reuse identifier for consistent cell dequeuing in table views.
protocol ReusableCell: UITableViewCell {
    static var reuseIdentifier: String { get }
}

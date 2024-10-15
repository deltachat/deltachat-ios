import UIKit

protocol ReusableCell: UITableViewCell {
    static var reuseIdentifier: String { get }
}

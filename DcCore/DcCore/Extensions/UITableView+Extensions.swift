import UIKit

extension UITableView {
  public func scrollToTop(animated: Bool = false) {
    let numberOfSections = self.numberOfSections
    if numberOfSections > 0 {
      let numberOfRows = self.numberOfRows(inSection: 0)
      if numberOfRows > 0 {
        let indexPath = IndexPath(row: 0, section: 0)
        self.scrollToRow(at: indexPath, at: UITableView.ScrollPosition.top, animated: animated)
      }
    }
  }
}

import UIKit

extension UIToolbar {
    func fillSuperviewAvoidingSafeAreaAndKeyboard() {
        guard let superview else { return }
        translatesAutoresizingMaskIntoConstraints = false
        leadingAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.trailingAnchor).isActive = true
        topAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.topAnchor, constant: 8).isActive = true
        let liquidGlassPadding = if #available(iOS 26, *) { 8.0 } else { 0.0 }
        bottomAnchor.constraint(lessThanOrEqualTo: superview.keyboardLayoutGuide.topAnchor, constant: -liquidGlassPadding).isActive = true
        let bottomToSafeArea = bottomAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.bottomAnchor)
        bottomToSafeArea.priority = .defaultLow
        bottomToSafeArea.isActive = true
    }
}

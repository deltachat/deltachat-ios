import UIKit

extension TestUtil {
    /// Adds a view to the root view controller that represents the safe area layout guide.
    /// You can then use this view to retreive the safe area in your UITests using `app.otherElements["safeAreaProvider"].frame`.
    static func addSafeAreaProvider() {
        let uitestSafeAreaProvider = UIView()
        uitestSafeAreaProvider.backgroundColor = .clear
        uitestSafeAreaProvider.isUserInteractionEnabled = false
        uitestSafeAreaProvider.accessibilityIdentifier = "safeAreaProvider"
        UIApplication.shared.delegate?.window??.rootViewController?.view.addSubview(uitestSafeAreaProvider)
        guard let superview = uitestSafeAreaProvider.superview else { fatalError("UITest: Safe area provider was not added") }
        uitestSafeAreaProvider.translatesAutoresizingMaskIntoConstraints = false
        uitestSafeAreaProvider.leftAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.leftAnchor).isActive = true
        uitestSafeAreaProvider.rightAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.rightAnchor).isActive = true
        uitestSafeAreaProvider.topAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.topAnchor).isActive = true
        uitestSafeAreaProvider.bottomAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.bottomAnchor).isActive = true
    }
}

import UIKit

/// Property wrapper that activates the newValue and deactivates the oldValue on didSet
@propertyWrapper struct ActivatedWhenSet {
    var wrappedValue: NSLayoutConstraint? {
        didSet {
            oldValue?.isActive = false
            wrappedValue?.isActive = true
        }
    }
}

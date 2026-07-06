import UIKit

public extension UIButton {
    private func applyStyle(_ config: UIButton.Configuration) {
        var config = config
        config.cornerStyle = .capsule
        config.buttonSize = .large
        configuration = config
    }

    func primaryCapsule() {
        let config = UIButton.Configuration.filled()
        applyStyle(config)
    }

    func secondaryCapsule() {
        let config = UIButton.Configuration.bordered()
        applyStyle(config)
    }
}

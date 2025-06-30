import UIKit

extension UIView {
    func blink(duration: Double = 0.2, repeatCount: Float = 2) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.duration = duration
        animation.fromValue = 1
        animation.toValue = 0.5
        animation.autoreverses = true
        animation.repeatCount = repeatCount
        layer.add(animation, forKey: "blink")
    }
}

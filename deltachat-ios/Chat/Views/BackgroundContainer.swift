import Foundation
import UIKit
import DcCore

class BackgroundContainer: UIImageView {

    var rectCorners: UIRectCorner?
    var color: UIColor?
    
    static func getCurrentCornerRadius() -> CGFloat {
        let radius = CGFloat(UserDefaults.standard.float(forKey: Constants.Keys.customBubbleCornerRadiusKey))
        return radius > 0 ? radius : 16.0
    }

    func update(rectCorners: UIRectCorner, color: UIColor) {
        self.rectCorners = rectCorners
        self.color = color
        image = UIImage(color: color)
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyPath()
    }

    func applyPath() {
        let radius = BackgroundContainer.getCurrentCornerRadius()
        let path = UIBezierPath(roundedRect: bounds,
                                byRoundingCorners: rectCorners ?? UIRectCorner(),
                                cornerRadii: CGSize(width: radius, height: radius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        layer.mask = mask
    }

    func prepareForReuse() {
        layer.mask = nil
        image = nil
        rectCorners = nil
        color = nil
        isHidden = false
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if let rectCorners = self.rectCorners, let color = self.color {
            update(rectCorners: rectCorners, color: color)
        }
    }

}

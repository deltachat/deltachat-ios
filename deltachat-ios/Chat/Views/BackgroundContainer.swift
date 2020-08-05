

import Foundation
import UIKit
import DcCore

class BackgroundContainer: UIImageView {

    var rectCorners: UIRectCorner?

    func update(rectCorners: UIRectCorner, color: UIColor) {
        self.rectCorners = rectCorners
        image = UIImage(color: color)
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyPath()
    }

    func applyPath() {
        let radius: CGFloat = 16
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
    }

}

import UIKit
import DcCore

class LocationStreamingIndicator: UIImageView {

    private let aspectRatio: CGFloat = 16/22

    convenience init() {
        self.init(frame: .zero)
    }

    convenience init(height: CGFloat) {
        let rect = CGRect(x: 0, y: 0, width: 0, height: height)
        self.init(frame: rect)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let size: CGFloat = frame == .zero ? 28 : frame.height
        setup(size: size)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(size: CGFloat) {
        tintColor = DcColors.checkmarkGreen
        image =  UIImage(named: "ic_location")?.withRenderingMode(.alwaysTemplate)
        translatesAutoresizingMaskIntoConstraints = false
        constraintHeightTo(size, priority: .defaultLow).isActive = true
        constraintWidthTo(aspectRatio * size).isActive = true
        contentMode = .scaleAspectFit
    }
}

import UIKit
import DcCore

class LocationStreamingIndicator: UIImageView {

    convenience init() {
        self.init(frame: .zero)
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
        image =  #imageLiteral(resourceName: "ic_location").withRenderingMode(.alwaysTemplate)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: size).isActive = true
        widthAnchor.constraint(equalToConstant: size).isActive = true
    }
}

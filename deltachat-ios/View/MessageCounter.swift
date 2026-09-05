import Foundation
import UIKit

class MessageCounter: UIView {

    private let minSize: CGFloat
    private var widthConstraint: NSLayoutConstraint?
    private let padding: CGFloat = 4

    private var label: UILabel = {
        let label = UILabel()
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = NSTextAlignment.center
        label.textColor = UIColor.white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isAccessibilityElement = false
        return label
    }()

    convenience init(count: Int, size: CGFloat) {
        self.init(size: size)
    }

    init(size: CGFloat) {
        self.minSize = size
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        let radius = size / 2
        layer.cornerRadius = radius
        translatesAutoresizingMaskIntoConstraints = false
        self.backgroundColor = UIColor.systemRed
        let initialWidthConstraint = widthAnchor.constraint(equalToConstant: size)
        widthConstraint = initialWidthConstraint
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: size),
            initialWidthConstraint,
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setCount(_ msgNo: Int) {
        let countString = NSAttributedString(string: String(msgNo), attributes: [.font: UIFont.systemFont(ofSize: 12)])
        let countStringSize = countString.width(considering: minSize) + padding
        if countStringSize > minSize {
            widthConstraint?.isActive = false
            widthConstraint = widthAnchor.constraint(equalToConstant: countStringSize)
            widthConstraint?.isActive = true
        } else if frame.width > minSize {
            widthConstraint?.isActive = false
            widthConstraint = widthAnchor.constraint(equalToConstant: minSize)
            widthConstraint?.isActive = true
        }
        label.attributedText = countString
    }

}

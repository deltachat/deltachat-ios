import UIKit

public extension UIView {

    static func borderedView(around subview: UIView, borderWidth: CGFloat, borderColor: UIColor, cornerRadius: CGFloat, padding: NSDirectionalEdgeInsets) -> UIView {
        let borderView = UIView()

        subview.translatesAutoresizingMaskIntoConstraints = false
        borderView.addSubview(subview)

        NSLayoutConstraint.activate([
            subview.topAnchor.constraint(equalTo: borderView.topAnchor, constant: padding.top),
            subview.leadingAnchor.constraint(equalTo: borderView.leadingAnchor, constant: padding.leading),
            borderView.trailingAnchor.constraint(equalTo: subview.trailingAnchor, constant: padding.trailing),
            borderView.bottomAnchor.constraint(equalTo: subview.bottomAnchor, constant: padding.bottom),
        ])

        borderView.layer.borderColor = borderColor.cgColor
        borderView.layer.borderWidth = borderWidth
        borderView.layer.cornerRadius = cornerRadius

        return borderView
    }

    func makeBorder(color: UIColor = UIColor.systemRed) {
        self.layer.borderColor = color.cgColor
        self.layer.borderWidth = 2
    }
}

import UIKit
import DcCore

class EmptyStateLabel: PaddingTextView {

    init(text: String? = nil) {
        super.init()
        backgroundColor = DcColors.systemMessageBackgroundColor
        label.textColor = DcColors.systemMessageFontColor
        layer.cornerRadius = 16
        label.clipsToBounds = true
        label.textAlignment = .center
        label.text = text
        paddingTop = 15
        paddingBottom = 15
        paddingLeading = 15
        paddingTrailing = 15
        translatesAutoresizingMaskIntoConstraints = false
    }

    func addCenteredTo(parentView: UIView, evadeKeyboard: Bool = false) {
        parentView.addSubview(self)
        leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 40).isActive = true
        trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -40).isActive = true
        let safeArea = parentView.safeAreaLayoutGuide
        centerXAnchor.constraint(equalTo: safeArea.centerXAnchor).isActive = true
        let centerYConstraint = centerYAnchor.constraint(equalTo: safeArea.centerYAnchor)
        centerYConstraint.isActive = true
        if #available(iOS 15.0, *), evadeKeyboard {
            centerYConstraint.priority = .defaultHigh
            bottomAnchor.constraint(lessThanOrEqualTo: parentView.keyboardLayoutGuide.topAnchor, constant: -40).isActive = true
        }

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

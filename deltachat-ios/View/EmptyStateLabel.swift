import UIKit
import DcCore

class EmptyStateLabel: PaddingTextView {

    override init() {
        super.init()
        backgroundColor = DcColors.systemMessageBackgroundColor
        label.textColor = DcColors.systemMessageFontColor
        layer.cornerRadius = 16
        label.clipsToBounds = true
        label.textAlignment = .center
        paddingTop = 15
        paddingBottom = 15
        paddingLeading = 15
        paddingTrailing = 15
        translatesAutoresizingMaskIntoConstraints = false
    }

    func addCenteredTo(parentView: UIView) {
        parentView.addSubview(self)
        leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 40).isActive = true
        trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -40).isActive = true
        centerYAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.centerYAnchor).isActive = true
        centerXAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.centerXAnchor).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

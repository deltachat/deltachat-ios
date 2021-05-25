import Foundation
import UIKit

class MultilineLabelCell: UITableViewCell {

    lazy var label: MessageLabel = {
        let label = MessageLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.isUserInteractionEnabled = true
        return label
    }()

    init() {
        super.init(style: .value1, reuseIdentifier: nil)
        selectionStyle = .none
        setupViews()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupViews() {
        contentView.addSubview(label)

        let margins = contentView.layoutMarginsGuide
        label.alignLeadingToAnchor(margins.leadingAnchor, paddingLeading: 0)
        label.alignTrailingToAnchor(margins.trailingAnchor)
        label.alignTopToAnchor(margins.topAnchor)
        label.alignBottomToAnchor(margins.bottomAnchor)
    }

    func setText(text: String?) {
        label.text = text
    }
}

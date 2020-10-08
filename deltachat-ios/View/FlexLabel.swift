import UIKit

/// view that contains a label (horizontally centered) and
/// allows it's label to grow/shrink within it's available space
class FlexLabel: UIView {

    var text: String? {
        set {
            label.text = newValue
        }
        get {
            return label.text
        }
    }

    var textColor: UIColor {
        set {
            label.textColor = newValue
        }
        get {
            return label.textColor
        }
    }

    var attributedText: NSAttributedString? {
        set {
            label.attributedText = newValue
        }
        get {
            return label.attributedText
        }
    }

    lazy var label: UILabel = {
        let label = PaddingLabel(top: 15, left: 15, bottom: 15, right: 15)
        label.numberOfLines = 0
        return label
    }()

    init() {
        super.init(frame: .zero)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0).isActive = true
        label.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 0).isActive = true
        label.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor).isActive = true
        label.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor).isActive = true
        label.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.95).isActive = true
    }
}

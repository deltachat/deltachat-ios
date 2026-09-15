import Foundation
import UIKit
import DcCore

class MultilineLabelCell: UITableViewCell {
    public weak var multilineDelegate: MultilineLabelCellDelegate?

    lazy var label: MessageLabel = {
        let label = MessageLabel()
        label.delegate = self
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(for: .body, weight: .regular)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.isUserInteractionEnabled = true
        label.enabledDetectors = [.url, .phoneNumber]
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor,
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
            NSAttributedString.Key.underlineColor: DcColors.defaultTextColor ]
        label.setAttributes(attributes, detector: .url)
        label.setAttributes(attributes, detector: .phoneNumber)
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
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            label.topAnchor.constraint(equalTo: margins.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: -10),
        ])

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        gestureRecognizer.numberOfTapsRequired = 1
        label.addGestureRecognizer(gestureRecognizer)
    }

    func setText(text: String?) {
        label.text = text
    }

    @objc
    open func handleTapGesture(_ gesture: UIGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let touchLocation = gesture.location(in: label)
        let isHandled = label.handleGesture(touchLocation)
        if !isHandled {
            logger.info("status: tapped outside urls or phone numbers")
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory {
            label.font = UIFont.preferredFont(for: .body, weight: .regular)
        }
    }
}

extension MultilineLabelCell: MessageLabelDelegate {
    public func didSelectAddress(_ addressComponents: [String: String]) {}

    public func didSelectDate(_ date: Date) {}

    public func didSelectPhoneNumber(_ phoneNumber: String) {
        multilineDelegate?.phoneNumberTapped(number: phoneNumber)
    }

    public func didSelectURL(_ url: URL) {
        multilineDelegate?.urlTapped(url: url)
    }

    public func didSelectTransitInformation(_ transitInformation: [String: String]) {}

    public func didSelectMention(_ mention: String) {}

    public func didSelectHashtag(_ hashtag: String) {}

    public func didSelectCommand(_ command: String) {}

    public func didSelectCustom(_ pattern: String, match: String?) {}
}

public protocol MultilineLabelCellDelegate: AnyObject {
    func phoneNumberTapped(number: String)
    func urlTapped(url: URL)
}

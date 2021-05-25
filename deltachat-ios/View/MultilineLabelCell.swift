import Foundation
import UIKit
import DcCore

class MultilineLabelCell: UITableViewCell {

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
        label.alignLeadingToAnchor(margins.leadingAnchor, paddingLeading: 0)
        label.alignTrailingToAnchor(margins.trailingAnchor)
        label.alignTopToAnchor(margins.topAnchor)
        label.alignBottomToAnchor(margins.bottomAnchor)
    }

    func setText(text: String?) {
        label.text = text
    }
}

extension MultilineLabelCell: MessageLabelDelegate {
    public func didSelectAddress(_ addressComponents: [String: String]) {}

    public func didSelectDate(_ date: Date) {}

    public func didSelectPhoneNumber(_ phoneNumber: String) {
        logger.info("status phone number tapped")
    }

    public func didSelectURL(_ url: URL) {
        logger.info("status URL tapped")
    }

    public func didSelectTransitInformation(_ transitInformation: [String: String]) {}

    public func didSelectMention(_ mention: String) {}

    public func didSelectHashtag(_ hashtag: String) {}

    public func didSelectCustom(_ pattern: String, match: String?) {}
}

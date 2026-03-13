import Foundation
import DcCore
import UIKit

class CallMessageCell: BaseMessageCell, ReusableCell {
    static let reuseIdentifier = "CallMessageCell"

    private let callTextTrailingPadding: CGFloat = 76
    private let callIconSize: CGFloat = 28
    private let callIconLeadingPadding: CGFloat = 8
    private let callIconTextPadding: CGFloat = 4
    private var callTitleFont: UIFont { UIFont.preferredFont(for: .callout, weight: .semibold) }
    private var callDurationFont: UIFont { UIFont.preferredFont(for: .caption1, weight: .regular) }
    private lazy var callTitleMinHeightConstraint = messageLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)

    private var callTextLeadingPadding: CGFloat {
        callIconLeadingPadding + callIconSize + callIconTextPadding
    }

    private lazy var durationLabel: PaddingTextView = {
        let view = PaddingTextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.font = callDurationFont
        view.textColor = DcColors.incomingMessageSecondaryTextColor
        view.numberOfLines = 1
        view.label.lineBreakMode = .byTruncatingTail
        view.isAccessibilityElement = false
        view.isHidden = true
        return view
    }()

    private lazy var callIconButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        button.setPreferredSymbolConfiguration(iconConfig, forImageIn: .normal)
        button.tintColor = DcColors.defaultTextColor
        button.isUserInteractionEnabled = false
        button.isAccessibilityElement = false
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            button.constraintWidthTo(callIconSize),
            button.constraintHeightTo(callIconSize)
        ])
        Self.configureCallIconButton(button, isVideoCall: false)
        return button
    }()

    override func prepareForReuse() {
        super.prepareForReuse()
        durationLabel.text = nil
        durationLabel.isHidden = true
        updateCallLayout(isVideoCall: false)
    }

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addArrangedSubview(messageLabel)
        mainContentView.addArrangedSubview(durationLabel)
        mainContentView.setCustomSpacing(2, after: messageLabel)
        messageBackgroundContainer.addSubview(callIconButton)
        NSLayoutConstraint.activate([
            callTitleMinHeightConstraint,
            callIconButton.constraintAlignLeadingTo(messageBackgroundContainer, paddingLeading: callIconLeadingPadding),
            callIconButton.centerYAnchor.constraint(equalTo: mainContentView.centerYAnchor)
        ])
        messageLabel.numberOfLines = 1
        messageLabel.label.lineBreakMode = .byTruncatingTail
        updateCallLayout(isVideoCall: false)
    }

    override func update(dcContext: DcContext, msg: DcMsg, callInfo: DcContext.CallInfo?, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, showViewCount: Bool, searchText: String?, highlight: Bool) {
        let isVideoCall = callInfo?.hasVideo == true
        updateCallLayout(isVideoCall: isVideoCall)

        super.update(dcContext: dcContext,
                     msg: msg,
                     callInfo: callInfo,
                     messageStyle: messageStyle,
                     showAvatar: showAvatar,
                     showName: showName,
                     showViewCount: showViewCount,
                     searchText: searchText,
                     highlight: highlight)

        durationLabel.textColor = durationTintColor(for: msg)
        applyCallTitle(message: msg, searchText: searchText, highlight: highlight)
    }

    private func updateCallLayout(isVideoCall: Bool) {
        messageLabel.paddingLeading = callTextLeadingPadding
        messageLabel.paddingTrailing = callTextTrailingPadding
        durationLabel.paddingLeading = callTextLeadingPadding
        durationLabel.paddingTrailing = callTextTrailingPadding
        callTitleMinHeightConstraint.constant = ceil(callTitleFont.lineHeight) + messageLabel.paddingTop + messageLabel.paddingBottom
        Self.configureCallIconButton(callIconButton, isVideoCall: isVideoCall)
    }

    private static func configureCallIconButton(_ button: UIButton, isVideoCall: Bool) {
        let imageName = isVideoCall ? "video" : "phone"
        button.setImage(UIImage(systemName: imageName), for: .normal)
    }

    private func applyCallTitle(message: DcMsg, searchText: String?, highlight: Bool) {
        guard let title = StatusView.callDisplayTitle(message: message, callInfo: currentCallInfo), !title.isEmpty else {
            messageLabel.attributedText = nil
            durationLabel.text = nil
            durationLabel.isHidden = true
            return
        }
        messageLabel.attributedText = formattedCallText(text: title, searchText: searchText, highlight: highlight)
        durationLabel.text = StatusView.callDurationText(callInfo: currentCallInfo)
        durationLabel.isHidden = durationLabel.text == nil
    }

    private func formattedCallText(text: String, searchText: String?, highlight: Bool) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: callTitleFont,
            .foregroundColor: DcColors.defaultTextColor
        ]
        let attributedText = NSMutableAttributedString(string: text, attributes: attributes)
        if let searchText {
            let ranges = text.ranges(of: searchText, options: .caseInsensitive)
            for range in ranges {
                let nsRange = NSRange(range, in: text)
                if highlight {
                    attributedText.addAttribute(.backgroundColor, value: DcColors.highlight, range: nsRange)
                }
            }
        }
        return attributedText
    }

    private func durationTintColor(for message: DcMsg) -> UIColor {
        if showBottomLabelBackground {
            return DcColors.coreDark05
        }
        if message.isFromCurrentSender {
            return DcColors.checkmarkGreen
        }
        return DcColors.incomingMessageSecondaryTextColor
    }
}

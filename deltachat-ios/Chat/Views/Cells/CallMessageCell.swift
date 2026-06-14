import Foundation
import DcCore
import UIKit

class CallMessageCell: BaseMessageCell, ReusableCell {
    static let reuseIdentifier = "CallMessageCell"

    private let callBubbleMinWidth: CGFloat = 240
    private let callTextTrailingPadding: CGFloat = 8
    private let callIconSize: CGFloat = 28
    private let callIconLeadingPadding: CGFloat = 8
    private let callIconTextPadding: CGFloat = 4
    private var callTitleFont: UIFont { UIFont.preferredFont(for: .callout, weight: .semibold) }
    private var callDurationFont: UIFont { UIFont.preferredFont(for: .caption1, weight: .regular) }
    private lazy var callTitleMinHeightConstraint = messageLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
    private var callInfo: DcContext.CallInfo?

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
        callInfo = nil
        durationLabel.text = nil
        durationLabel.isHidden = true
        updateCallLayout(isVideoCall: false)
    }

    func configure(callInfo: DcContext.CallInfo?) {
        self.callInfo = callInfo
    }

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addArrangedSubview(messageLabel)
        mainContentView.addArrangedSubview(durationLabel)
        mainContentView.setCustomSpacing(2, after: messageLabel)
        messageBackgroundContainer.addSubview(callIconButton)
        NSLayoutConstraint.activate([
            callTitleMinHeightConstraint,
            messageBackgroundContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: callBubbleMinWidth),
            callIconButton.constraintAlignLeadingTo(messageBackgroundContainer, paddingLeading: callIconLeadingPadding),
            callIconButton.centerYAnchor.constraint(equalTo: mainContentView.centerYAnchor)
        ])
        messageLabel.numberOfLines = 1
        messageLabel.label.lineBreakMode = .byTruncatingTail
        updateCallLayout(isVideoCall: false)
    }

    override func update(dcContext: DcContext, msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, showViewCount: Bool, searchText: String?, highlight: Bool) {
        let isVideoCall = callInfo?.hasVideo == true
        updateCallLayout(isVideoCall: isVideoCall)

        super.update(dcContext: dcContext,
                     msg: msg,
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
        guard let title = callDisplayTitle(message: message), !title.isEmpty else {
            messageLabel.attributedText = nil
            durationLabel.text = nil
            durationLabel.isHidden = true
            return
        }
        messageLabel.attributedText = formattedCallText(text: title, searchText: searchText, highlight: highlight)
        durationLabel.text = callDurationText()
        durationLabel.isHidden = durationLabel.text == nil
    }

    override func additionalAccessibilityText(message _: DcMsg) -> String {
        guard let duration = callDurationText() else {
            return ""
        }
        return "\(duration), "
    }

    private func callDisplayTitle(message: DcMsg) -> String? {
        if let localizationKey = callLocalizationKey() {
            return String.localized(localizationKey)
        }
        if let text = message.text, !text.isEmpty {
            return text
        }
        return String.localized("audio_call")
    }

    private func callLocalizationKey() -> String? {
        guard let callInfo else {
            return nil
        }

        switch callInfo.state {
        case .missed:
            return "missed_call"
        case .declined:
            return "declined_call"
        case .canceled:
            return "canceled_call"
        case .alerting, .active, .completed, .unknown:
            return callInfo.hasVideo ? "video_call" : "audio_call"
        }
    }

    private func callDurationText() -> String? {
        guard let durationSeconds = callDurationSeconds() else {
            return nil
        }
        let durationMinutes = max(0, durationSeconds) / 60
        if durationMinutes == 0 {
            return String.localized("call_duration_less_than_a_minute")
        }
        return String.localized(stringID: "call_duration_minutes", parameter: durationMinutes)
    }

    private func callDurationSeconds() -> Int? {
        guard let state = callInfo?.state else {
            return nil
        }

        switch state {
        case .completed(let duration):
            return duration
        case .unknown(_, let duration):
            return duration
        case .alerting, .active, .missed, .declined, .canceled:
            return nil
        }
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

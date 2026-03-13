import Foundation
import DcCore
import UIKit

class CallMessageCell: BaseMessageCell, ReusableCell {
    static let reuseIdentifier = "CallMessageCell"

    private let defaultTextPadding: CGFloat = 12
    private let callIconSize: CGFloat = 28
    private let callIconTrailingPadding: CGFloat = 10
    private let callIconTextPadding: CGFloat = 16
    private var callTitleFont: UIFont { UIFont.preferredFont(for: .callout, weight: .semibold) }
    private lazy var callTitleMinHeightConstraint = messageLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
    private lazy var statusViewTrailingToCallIconConstraint = statusView.trailingAnchor.constraint(lessThanOrEqualTo: callIconButton.leadingAnchor, constant: -callIconTextPadding)
    private let callTextBlockLayoutGuide = UILayoutGuide()

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
        updateCallLayout(isVideoCall: false)
    }

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addArrangedSubview(messageLabel)
        messageBackgroundContainer.addSubview(callIconButton)
        messageBackgroundContainer.addLayoutGuide(callTextBlockLayoutGuide)
        NSLayoutConstraint.activate([
            callTitleMinHeightConstraint,
            callIconButton.constraintAlignTrailingTo(messageBackgroundContainer, paddingTrailing: callIconTrailingPadding),
            callIconButton.centerYAnchor.constraint(equalTo: callTextBlockLayoutGuide.centerYAnchor),
            statusViewTrailingToCallIconConstraint,
            callTextBlockLayoutGuide.topAnchor.constraint(equalTo: mainContentView.topAnchor),
            callTextBlockLayoutGuide.bottomAnchor.constraint(equalTo: statusView.bottomAnchor)
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

        applyCallTitle(message: msg, searchText: searchText, highlight: highlight)
    }

    private func updateCallLayout(isVideoCall: Bool) {
        messageLabel.paddingLeading = defaultTextPadding
        messageLabel.paddingTrailing = callIconSize + callIconTrailingPadding + callIconTextPadding
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
            return
        }
        messageLabel.attributedText = formattedCallText(text: title, searchText: searchText, highlight: highlight)
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
}

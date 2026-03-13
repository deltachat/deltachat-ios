import Foundation
import UIKit
import DcCore

public class StatusView: UIView {
    private let contentStackView: UIStackView
    let dateLabel: UILabel
    private let editedLabel: UILabel
    private let callDirectionView: UIImageView
    private let envelopeView: UIImageView
    private let locationView: UIImageView
    private let viewsIconView: UIImageView
    private let viewsCountLabel: UILabel
    private let stateView: UIImageView
    private let savedView: UIImageView
    private let defaultSpacing: CGFloat = 4
    private let viewsSectionLeadingSpacing: CGFloat = 10

    private lazy var callDirectionSymbolConfiguration = UIImage.SymbolConfiguration(
        pointSize: max(6, UIFont.preferredFont(for: .caption2, weight: .regular).pointSize - 4),
        weight: .regular
    )

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .short
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter
    }()

    private static let incomingCallDirectionSymbol = UIImage(systemName: "arrow.down.left")
    private static let outgoingCallDirectionSymbol = UIImage(systemName: "arrow.up.right")

    override init(frame: CGRect) {

        dateLabel = UILabel()
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = UIFont.preferredFont(for: .caption1, weight: .regular)

        editedLabel = UILabel()
        editedLabel.text = String.localized("edited")
        editedLabel.translatesAutoresizingMaskIntoConstraints = false
        editedLabel.font = UIFont.preferredFont(for: .caption1, weight: .regular)

        callDirectionView = UIImageView()
        callDirectionView.translatesAutoresizingMaskIntoConstraints = false
        callDirectionView.contentMode = .scaleAspectFit
        callDirectionView.setContentCompressionResistancePriority(.required, for: .horizontal)
        callDirectionView.setContentCompressionResistancePriority(.required, for: .vertical)
        callDirectionView.setContentHuggingPriority(.required, for: .horizontal)
        callDirectionView.setContentHuggingPriority(.required, for: .vertical)

        envelopeView = UIImageView()
        envelopeView.translatesAutoresizingMaskIntoConstraints = false
        locationView = UIImageView()
        locationView.translatesAutoresizingMaskIntoConstraints = false
        viewsIconView = UIImageView()
        viewsIconView.translatesAutoresizingMaskIntoConstraints = false
        viewsCountLabel = UILabel()
        viewsCountLabel.translatesAutoresizingMaskIntoConstraints = false
        viewsCountLabel.font = UIFont.preferredFont(for: .caption1, weight: .regular)
        stateView = UIImageView()
        stateView.translatesAutoresizingMaskIntoConstraints = false
        savedView = UIImageView()
        savedView.translatesAutoresizingMaskIntoConstraints = false

        contentStackView = UIStackView(arrangedSubviews: [savedView, envelopeView, editedLabel, callDirectionView, dateLabel, locationView, viewsIconView, viewsCountLabel, stateView])
        contentStackView.alignment = .center
        contentStackView.spacing = defaultSpacing
        contentStackView.setCustomSpacing(2, after: viewsIconView)
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        super.init(frame: frame)

        addSubview(contentStackView)

        layer.cornerRadius = 5

        setupConstraints()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: 5),
            bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor),

            callDirectionView.widthAnchor.constraint(greaterThanOrEqualToConstant: 12),
            callDirectionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 12),

            envelopeView.widthAnchor.constraint(equalToConstant: 14),
            envelopeView.heightAnchor.constraint(equalToConstant: 10),

            locationView.widthAnchor.constraint(equalToConstant: 10),
            locationView.heightAnchor.constraint(equalToConstant: 14),

            viewsIconView.widthAnchor.constraint(equalToConstant: 14),
            viewsIconView.heightAnchor.constraint(equalToConstant: 10),

            stateView.widthAnchor.constraint(equalToConstant: 20),
            stateView.heightAnchor.constraint(equalToConstant: 20),

            savedView.widthAnchor.constraint(equalToConstant: 6),
            savedView.heightAnchor.constraint(equalToConstant: 11),
        ])
    }


    public func prepareForReuse() {
        dateLabel.text = nil
        editedLabel.isHidden = true
        envelopeView.isHidden = true
        locationView.isHidden = true
        viewsIconView.isHidden = true
        viewsCountLabel.isHidden = true
        viewsCountLabel.text = nil
        savedView.isHidden = true
        callDirectionView.image = nil
        callDirectionView.isHidden = true
        stateView.isHidden = true
    }

    public func update(message: DcMsg, tintColor: UIColor, showOnlyPendingAndError: Bool = false, viewCount: Int? = nil) {
        update(message: message, callInfo: nil, tintColor: tintColor, showOnlyPendingAndError: showOnlyPendingAndError, viewCount: viewCount)
    }

    public func update(message: DcMsg, callInfo: DcContext.CallInfo?, tintColor: UIColor, showOnlyPendingAndError: Bool = false, viewCount: Int? = nil) {
        dateLabel.text = Self.statusDateText(message: message, callInfo: callInfo)
        dateLabel.textColor = tintColor
        editedLabel.isHidden = !message.isEdited
        editedLabel.textColor = tintColor
        updateCallDirectionView(message: message, callInfo: callInfo, tintColor: tintColor)

        if message.showEnvelope() {
            envelopeView.image = UIImage(systemName: "envelope")?.maskWithColor(color: tintColor)
            envelopeView.isHidden = false
        } else {
            envelopeView.isHidden = true
        }

        if message.hasLocation {
            locationView.image = UIImage(named: "ic_location")?.maskWithColor(color: tintColor)
            locationView.isHidden = false
        } else {
            locationView.isHidden = true
        }

        if let viewCount {
            viewsIconView.image = UIImage(systemName: "eye")?.maskWithColor(color: tintColor)
            viewsIconView.isHidden = false
            viewsCountLabel.text = "\(viewCount)"
            viewsCountLabel.textColor = tintColor
            viewsCountLabel.isHidden = false
        } else {
            viewsIconView.isHidden = true
            viewsCountLabel.isHidden = true
            viewsCountLabel.text = nil
        }
        updateViewsSectionSpacing(hasLocation: message.hasLocation, showViewCount: viewCount != nil)

        if message.savedMessageId != 0 || message.originalMessageId != 0 {
            savedView.image = UIImage(systemName: "bookmark.fill")?.maskWithColor(color: tintColor)
            savedView.isHidden = false
        } else {
            savedView.isHidden = true
        }

        if message.type == DC_MSG_CALL {
            stateView.image = nil
            stateView.isHidden = true
            return
        }

        let state: Int
        if message.downloadState == DC_DOWNLOAD_IN_PROGRESS {
            state = Int(DC_DOWNLOAD_IN_PROGRESS)
        } else if message.fromContactId == Int(DC_CONTACT_ID_SELF) {
            state = message.state
        } else {
            state = 0
        }

        switch Int32(state) {
        case DC_DOWNLOAD_IN_PROGRESS, DC_STATE_OUT_PENDING, DC_STATE_OUT_PREPARING:
            stateView.image = UIImage(named: "ic_hourglass_empty_white_36pt")?.maskWithColor(color: tintColor)
        case DC_STATE_OUT_DELIVERED:
            stateView.image = showOnlyPendingAndError ? nil : UIImage(named: "ic_done_36pt")?.maskWithColor(color: tintColor)
        case DC_STATE_OUT_MDN_RCVD:
            stateView.image = showOnlyPendingAndError ? nil : UIImage(named: "ic_done_all_36pt")?.maskWithColor(color: tintColor)
        case DC_STATE_OUT_FAILED:
            stateView.image = UIImage(named: "ic_error_36pt")
        default:
            stateView.image = nil
        }
        stateView.isHidden = stateView.image == nil
    }

    static func statusDateText(message: DcMsg, callInfo: DcContext.CallInfo?) -> String {
        if message.type != DC_MSG_CALL {
            return message.formattedSentDate()
        }

        let sentDateText = DateUtils.getExtendedAbsTimeSpanString(timeStamp: Double(message.timestamp))
        guard let durationText = callDurationText(callInfo: callInfo) else {
            return sentDateText
        }
        return "\(sentDateText), \(durationText)"
    }

    private static func callDurationText(callInfo: DcContext.CallInfo?) -> String? {
        guard let durationSeconds = callDurationSeconds(state: callInfo?.state) else {
            return nil
        }
        return durationFormatter.string(from: TimeInterval(max(0, durationSeconds)))
    }

    private static func callDurationSeconds(state: DcContext.CallInfoState?) -> Int? {
        guard let state else {
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

    private func updateCallDirectionView(message: DcMsg, callInfo: DcContext.CallInfo?, tintColor: UIColor) {
        guard message.type == DC_MSG_CALL else {
            callDirectionView.image = nil
            callDirectionView.isHidden = true
            return
        }

        let symbol = message.isFromCurrentSender ? Self.outgoingCallDirectionSymbol : Self.incomingCallDirectionSymbol
        guard let symbolImage = symbol?.withConfiguration(callDirectionSymbolConfiguration) else {
            callDirectionView.image = nil
            callDirectionView.isHidden = true
            return
        }

        callDirectionView.image = symbolImage.withRenderingMode(.alwaysTemplate)
        callDirectionView.tintColor = callDirectionTintColor(callInfo: callInfo, defaultTintColor: tintColor)
        callDirectionView.isHidden = false
    }

    private func callDirectionTintColor(callInfo: DcContext.CallInfo?, defaultTintColor: UIColor) -> UIColor {
        guard let state = callInfo?.state else {
            return defaultTintColor
        }

        switch state {
        case .missed, .declined, .canceled:
            return .systemRed
        case .alerting, .active:
            return defaultTintColor
        case .completed, .unknown:
            return DcColors.checkmarkGreen
        }
    }

    static func callDisplayTitle(message: DcMsg, callInfo: DcContext.CallInfo?) -> String? {
        if let localizationKey = callLocalizationKey(callInfo: callInfo) {
            return String.localized(localizationKey)
        }
        if let text = message.text, !text.isEmpty {
            return text
        }
        return String.localized("audio_call")
    }

    private static func callLocalizationKey(callInfo: DcContext.CallInfo?) -> String? {
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

    public static func getAccessibilityString(message: DcMsg, callInfo: DcContext.CallInfo? = nil, showOnlyPendingAndError: Bool = false, viewCount: Int? = nil) -> String {
        if message.type == DC_MSG_CALL {
            return statusDateText(message: message, callInfo: callInfo)
        }

        let state: String
        switch Int32(message.state) {
        case DC_STATE_OUT_PENDING, DC_STATE_OUT_PREPARING:
            state = String.localized("a11y_delivery_status_sending")
        case DC_STATE_OUT_DELIVERED:
            state = showOnlyPendingAndError ? "" : String.localized("a11y_delivery_status_delivered")
        case DC_STATE_OUT_MDN_RCVD:
            state = showOnlyPendingAndError ? "" : String.localized("a11y_delivery_status_read")
        case DC_STATE_OUT_FAILED:
            state = String.localized("a11y_delivery_status_error")
        default:
            state = ""
        }
        let stateString = state.isEmpty ? "" : ", \(state)"
        let viewsCountString: String
        if let viewCount {
            viewsCountString = ", " + String.localized(stringID: "n_views", parameter: Int(viewCount))
        } else {
            viewsCountString = ""
        }
        let envelopeString = message.showEnvelope() ? (", " + String.localized("email")) : ""
        return "\(message.formattedSentDate())\(stateString)\(viewsCountString)\(envelopeString)"
    }

    private func updateViewsSectionSpacing(hasLocation: Bool, showViewCount: Bool) {
        contentStackView.setCustomSpacing(defaultSpacing, after: dateLabel)
        contentStackView.setCustomSpacing(defaultSpacing, after: locationView)
        if showViewCount {
            if hasLocation {
                contentStackView.setCustomSpacing(viewsSectionLeadingSpacing, after: locationView)
            } else {
                contentStackView.setCustomSpacing(viewsSectionLeadingSpacing, after: dateLabel)
            }
        }
    }
}

import Foundation
import UIKit
import DcCore

public class StatusView: UIStackView {
    private lazy var dateLabel: UILabel = {
        let title = UILabel()
        title.font = UIFont.preferredFont(for: .caption1, weight: .regular)
        return title
    }()

    private lazy var padlockView: UIImageView = {
        return UIImageView()
    }()

    private lazy var locationView: UIImageView = {
        return UIImageView()
    }()

    private lazy var stateView: UIImageView = {
        return UIImageView()
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addArrangedSubview(dateLabel)
        addArrangedSubview(padlockView)
        addArrangedSubview(locationView)
        addArrangedSubview(stateView)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.defaultHigh, for: .horizontal)
        setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        isAccessibilityElement = false
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func prepareForReuse() {
        dateLabel.text = nil
        padlockView.isHidden = true
        locationView.isHidden = true
        stateView.isHidden = true
    }

    public func update(message: DcMsg, tintColor: UIColor) {
        dateLabel.text = message.formattedSentDate()
        dateLabel.textColor = tintColor

        if message.showPadlock() {
            padlockView.image = UIImage(named: "ic_lock")?.maskWithColor(color: tintColor)
            padlockView.isHidden = false
        } else {
            padlockView.isHidden = true
        }

        if message.hasLocation {
            locationView.image = UIImage(named: "ic_location")?.maskWithColor(color: tintColor)?.scaleDownImage(toMax: 12)
            locationView.isHidden = false
        } else {
            locationView.isHidden = true
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
            stateView.image = #imageLiteral(resourceName: "ic_hourglass_empty_white_36pt").scaleDownImage(toMax: 14)?.maskWithColor(color: tintColor)
        case DC_STATE_OUT_DELIVERED:
            stateView.image = #imageLiteral(resourceName: "ic_done_36pt").scaleDownImage(toMax: 16)?.sd_croppedImage(with: CGRect(x: 0, y: 4, width: 16, height: 14))?.maskWithColor(color: tintColor)
        case DC_STATE_OUT_MDN_RCVD:
            stateView.image = #imageLiteral(resourceName: "ic_done_all_36pt").scaleDownImage(toMax: 16)?.sd_croppedImage(with: CGRect(x: 0, y: 4, width: 16, height: 14))?.maskWithColor(color: tintColor)
        case DC_STATE_OUT_FAILED:
            stateView.image = #imageLiteral(resourceName: "ic_error_36pt").scaleDownImage(toMax: 14)
        default:
            stateView.image = nil
        }
        stateView.isHidden = stateView.image == nil
    }
}

public class MessageUtils {
    public static func getFormattedBottomLineAccessibilityString(message: DcMsg) -> String {
        let padlock =  message.showPadlock() ? "\(String.localized("encrypted_message")), " : ""
        let state: String
        switch Int32(message.state) {
        case DC_STATE_OUT_PENDING, DC_STATE_OUT_PREPARING:
            state = String.localized("a11y_delivery_status_sending")
        case DC_STATE_OUT_DELIVERED:
            state = String.localized("a11y_delivery_status_delivered")
        case DC_STATE_OUT_MDN_RCVD:
            state = String.localized("a11y_delivery_status_read")
        case DC_STATE_OUT_FAILED:
            state = String.localized("a11y_delivery_status_error")
        default:
            state = ""
        }
        return "\(message.formattedSentDate()), \(padlock) \(state)"
    }

    public static func getFormattedTextMessage(messageText: String?, searchText: String?, highlight: Bool) -> NSAttributedString? {
        if let messageText = messageText {

            var fontSize = UIFont.preferredFont(for: .body, weight: .regular).pointSize
            // calculate jumbomoji size
            let charCount = messageText.count
            if charCount <= 8 && messageText.containsOnlyEmoji {
                if charCount <= 2 {
                    fontSize *= 3.0
                } else if charCount <= 4 {
                    fontSize *= 2.5
                } else if charCount <= 6 {
                    fontSize *= 1.75
                } else {
                    fontSize *= 1.35
                }
            }

            let fontAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: DcColors.defaultTextColor
            ]
            let mutableAttributedString = NSMutableAttributedString(string: messageText, attributes: fontAttributes)

            if let searchText = searchText {
                let ranges = messageText.ranges(of: searchText, options: .caseInsensitive)
                for range in ranges {
                    let nsRange = NSRange(range, in: messageText)
                    mutableAttributedString.addAttribute(.font, value: UIFont.preferredFont(for: .body, weight: .semibold), range: nsRange)
                    if highlight {
                        mutableAttributedString.addAttribute(.backgroundColor, value: DcColors.highlight, range: nsRange)
                    }
                }
            }
            return mutableAttributedString
        }

        return nil
    }
}

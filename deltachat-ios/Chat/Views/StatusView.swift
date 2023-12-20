import Foundation
import UIKit
import DcCore

public class StatusView: UIStackView {
    private var dateLabel: UILabel
    private var padlockView: UIImageView
    private var locationView: UIImageView
    private var stateView: UIImageView

    override init(frame: CGRect) {
        dateLabel = UILabel()
        dateLabel.font = UIFont.preferredFont(for: .caption1, weight: .regular)

        padlockView = UIImageView()
        padlockView.widthAnchor.constraint(equalToConstant: 15).isActive = true
        padlockView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        locationView = UIImageView()
        locationView.widthAnchor.constraint(equalToConstant: 8).isActive = true
        locationView.heightAnchor.constraint(equalToConstant: 11).isActive = true

        stateView = UIImageView()
        stateView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        stateView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        super.init(frame: frame)

        addArrangedSubview(dateLabel)
        addArrangedSubview(padlockView)
        addArrangedSubview(locationView)
        addArrangedSubview(stateView)
        alignment = .center
        spacing = 0
        translatesAutoresizingMaskIntoConstraints = false
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
            locationView.image = UIImage(named: "ic_location")?.maskWithColor(color: tintColor)
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
            stateView.image = #imageLiteral(resourceName: "ic_hourglass_empty_white_36pt").maskWithColor(color: tintColor)
        case DC_STATE_OUT_DELIVERED:
            stateView.image = #imageLiteral(resourceName: "ic_done_36pt").maskWithColor(color: tintColor)
        case DC_STATE_OUT_MDN_RCVD:
            stateView.image = #imageLiteral(resourceName: "ic_done_all_36pt").maskWithColor(color: tintColor)
        case DC_STATE_OUT_FAILED:
            stateView.image = #imageLiteral(resourceName: "ic_error_36pt")
        default:
            stateView.image = nil
        }
        stateView.isHidden = stateView.image == nil
    }

    public static func getAccessibilityString(message: DcMsg) -> String {
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
        return "\(message.formattedSentDate()), \(state)\(message.showPadlock() ? ", " + String.localized("encrypted_message") : "")"
    }
}

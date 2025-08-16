import Foundation
import UIKit
import DcCore

public class StatusView: UIView {
    private let contentStackView: UIStackView
    let dateLabel: UILabel
    private let editedLabel: UILabel
    private let envelopeView: UIImageView
    private let locationView: UIImageView
    private let stateView: UIImageView
    private let savedView: UIImageView

    override init(frame: CGRect) {

        dateLabel = UILabel()
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = UIFont.preferredFont(for: .caption1, weight: .regular)

        editedLabel = UILabel()
        editedLabel.text = String.localized("edited")
        editedLabel.translatesAutoresizingMaskIntoConstraints = false
        editedLabel.font = UIFont.preferredFont(for: .caption1, weight: .regular)

        envelopeView = UIImageView()
        envelopeView.translatesAutoresizingMaskIntoConstraints = false
        locationView = UIImageView()
        locationView.translatesAutoresizingMaskIntoConstraints = false
        stateView = UIImageView()
        stateView.translatesAutoresizingMaskIntoConstraints = false
        savedView = UIImageView()
        savedView.translatesAutoresizingMaskIntoConstraints = false

        contentStackView = UIStackView(arrangedSubviews: [savedView, envelopeView, editedLabel, dateLabel, locationView, stateView])
        contentStackView.alignment = .center
        contentStackView.spacing = 4
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        super.init(frame: frame)

        addSubview(contentStackView)

        layer.cornerRadius = 5

        setupConstraints()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [

            contentStackView.topAnchor.constraint(equalTo: topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: 5),
            bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor),

            envelopeView.widthAnchor.constraint(equalToConstant: 14),
            envelopeView.heightAnchor.constraint(equalToConstant: 10),

            locationView.widthAnchor.constraint(equalToConstant: 10),
            locationView.heightAnchor.constraint(equalToConstant: 14),

            stateView.widthAnchor.constraint(equalToConstant: 20),
            stateView.heightAnchor.constraint(equalToConstant: 20),

            savedView.widthAnchor.constraint(equalToConstant: 6),
            savedView.heightAnchor.constraint(equalToConstant: 11),
        ]

        NSLayoutConstraint.activate(constraints)
    }


    public func prepareForReuse() {
        dateLabel.text = nil
        editedLabel.isHidden = true
        envelopeView.isHidden = true
        locationView.isHidden = true
        savedView.isHidden = true
        stateView.isHidden = true
    }

    public func update(message: DcMsg, tintColor: UIColor) {
        dateLabel.text = message.formattedSentDate()
        dateLabel.textColor = tintColor
        editedLabel.isHidden = !message.isEdited
        editedLabel.textColor = tintColor

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

        if message.savedMessageId != 0 || message.originalMessageId != 0 {
            savedView.image = UIImage(systemName: "bookmark.fill")?.maskWithColor(color: tintColor)
            savedView.isHidden = false
        } else {
            savedView.isHidden = true
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
            stateView.image = UIImage(named: "ic_done_36pt")?.maskWithColor(color: tintColor)
        case DC_STATE_OUT_MDN_RCVD:
            stateView.image = UIImage(named: "ic_done_all_36pt")?.maskWithColor(color: tintColor)
        case DC_STATE_OUT_FAILED:
            stateView.image = UIImage(named: "ic_error_36pt")
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
        return "\(message.formattedSentDate()), \(state)\(message.showEnvelope() ? (", " + String.localized("email")) : "")"
    }
}

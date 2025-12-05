import Foundation
import UIKit
import DcCore

public class StatusView: UIView {
    private let leftStackView: UIStackView
    private let contentStackView: UIStackView
    let dateLabel: UILabel
    let durationLabel: UILabel
    let separatorLabel: UILabel
    let speedButton: UIButton
    private let editedLabel: UILabel
    private let envelopeView: UIImageView
    private let locationView: UIImageView
    private let stateView: UIImageView
    private let savedView: UIImageView

    override init(frame: CGRect) {

        dateLabel = UILabel()
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = UIFont.preferredFont(for: .caption1, weight: .regular)

        durationLabel = UILabel()
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.font = UIFont.preferredFont(for: .caption1, weight: .regular)
        durationLabel.isHidden = true

        separatorLabel = UILabel()
        separatorLabel.text = "•"
        separatorLabel.translatesAutoresizingMaskIntoConstraints = false
        separatorLabel.font = UIFont.preferredFont(for: .caption1, weight: .regular)
        separatorLabel.isHidden = true

        speedButton = UIButton(type: .custom)
        speedButton.setTitle("1x", for: .normal)
        speedButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .caption1)
        speedButton.titleLabel?.adjustsFontForContentSizeCategory = true
        speedButton.setTitleColor(.label, for: .normal)
        speedButton.backgroundColor = UIColor.systemGray5
        speedButton.layer.cornerRadius = 8
        speedButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        speedButton.translatesAutoresizingMaskIntoConstraints = false
        speedButton.isUserInteractionEnabled = true
        speedButton.isHidden = true

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

        leftStackView = UIStackView(arrangedSubviews: [durationLabel, separatorLabel, speedButton])
        leftStackView.alignment = .center
        leftStackView.spacing = 4
        leftStackView.translatesAutoresizingMaskIntoConstraints = false
        
        
        contentStackView = UIStackView(arrangedSubviews: [savedView, envelopeView, editedLabel, dateLabel, locationView, stateView])
        contentStackView.alignment = .center
        contentStackView.spacing = 4
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        super.init(frame: frame)

        addSubview(leftStackView)
        addSubview(contentStackView)

        layer.cornerRadius = 5

        setupConstraints()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            // Left stack view (duration • speed) on the left
            leftStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            leftStackView.centerYAnchor.constraint(equalTo: contentStackView.centerYAnchor),
            
            // Fixed width for duration label to keep dot position stable
            durationLabel.widthAnchor.constraint(equalToConstant: 30),
            
            // Fixed width for speed button to prevent resizing when text changes
            speedButton.widthAnchor.constraint(equalToConstant: 36),
            
            // Content stack view on the right
            contentStackView.topAnchor.constraint(equalTo: topAnchor),
            contentStackView.leadingAnchor.constraint(greaterThanOrEqualTo: leftStackView.trailingAnchor, constant: 8),
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
        durationLabel.text = nil
        durationLabel.isHidden = true
        separatorLabel.isHidden = true
        speedButton.setTitle(nil, for: .normal)
        speedButton.isHidden = true
        editedLabel.isHidden = true
        envelopeView.isHidden = true
        locationView.isHidden = true
        savedView.isHidden = true
        stateView.isHidden = true
    }

    public func update(message: DcMsg, tintColor: UIColor) {
        dateLabel.text = message.formattedSentDate()
        dateLabel.textColor = tintColor
        durationLabel.textColor = tintColor
        separatorLabel.textColor = tintColor
        speedButton.setTitleColor(tintColor, for: .normal)
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

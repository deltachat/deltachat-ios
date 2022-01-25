import Foundation
import UIKit
import DcCore


public class MessageUtils {
    static func getFormattedBottomLine(message: DcMsg, tintColor: UIColor) -> NSAttributedString {

        var paragraphStyle = NSParagraphStyle()
        if let style = NSMutableParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle {
            paragraphStyle = style
        }

        var timestampAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(for: .caption1, weight: .regular),
            .foregroundColor: tintColor,
            .paragraphStyle: paragraphStyle,
        ]

        let text = NSMutableAttributedString()
        if message.fromContactId == Int(DC_CONTACT_ID_SELF) {
            if let style = NSMutableParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle {
                style.alignment = .right
                timestampAttributes[.paragraphStyle] = style
            }

            text.append(NSAttributedString(string: message.formattedSentDate(), attributes: timestampAttributes))
            if message.showPadlock() {
                attachPadlock(to: text, color: tintColor)
            }

            if message.hasLocation {
                attachLocation(to: text, color: tintColor)
            }

            let messageState = message.downloadState == DC_DOWNLOAD_IN_PROGRESS ?
                Int(DC_DOWNLOAD_IN_PROGRESS) :
                message.state
            attachSendingState(messageState, to: text, color: tintColor)
            return text
        }

        if message.downloadState == DC_DOWNLOAD_IN_PROGRESS {
            attachSendingState(Int(DC_DOWNLOAD_IN_PROGRESS), to: text, color: tintColor)
        }
        
        text.append(NSAttributedString(string: message.formattedSentDate(), attributes: timestampAttributes))
        if message.showPadlock() {
            attachPadlock(to: text, color: tintColor)
        }

        if message.hasLocation {
            attachLocation(to: text, color: tintColor)
        }

        return text
    }

    private static func attachLocation(to text: NSMutableAttributedString, color: UIColor) {
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(named: "ic_location")?.maskWithColor(color: color)?.scaleDownImage(toMax: 12)

        let imageString = NSMutableAttributedString(attachment: imageAttachment)
        imageString.addAttributes([NSAttributedString.Key.baselineOffset: -0.5], range: NSRange(location: 0, length: 1))
        text.append(NSAttributedString(string: "\u{202F}"))
        text.append(imageString)
    }

    private static func attachPadlock(to text: NSMutableAttributedString, color: UIColor) {
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(named: "ic_lock")?.maskWithColor(color: color)?.scaleDownImage(toMax: 15)
        let imageString = NSMutableAttributedString(attachment: imageAttachment)
        imageString.addAttributes([NSAttributedString.Key.baselineOffset: -0.5], range: NSRange(location: 0, length: 1))
        text.append(NSAttributedString(string: " "))
        text.append(imageString)
    }

    private static func getSendingStateString(_ state: Int) -> String {
        switch Int32(state) {
        case DC_STATE_OUT_PENDING, DC_STATE_OUT_PREPARING:
            return String.localized("a11y_delivery_status_sending")
        case DC_STATE_OUT_DELIVERED:
            return String.localized("a11y_delivery_status_delivered")
        case DC_STATE_OUT_MDN_RCVD:
            return String.localized("a11y_delivery_status_read")
        case DC_STATE_OUT_FAILED:
            return String.localized("a11y_delivery_status_error")
        default:
            return ""
        }
    }

    private static func attachSendingState(_ state: Int, to text: NSMutableAttributedString, color: UIColor) {
        let imageAttachment = NSTextAttachment()
        var offset: CGFloat = -2

        switch Int32(state) {
        case DC_STATE_OUT_PENDING, DC_STATE_OUT_PREPARING, DC_DOWNLOAD_IN_PROGRESS:
            imageAttachment.image = #imageLiteral(resourceName: "ic_hourglass_empty_white_36pt").scaleDownImage(toMax: 14)?.maskWithColor(color: color)
        case DC_STATE_OUT_DELIVERED:
            imageAttachment.image = #imageLiteral(resourceName: "ic_done_36pt").scaleDownImage(toMax: 16)?.sd_croppedImage(with: CGRect(x: 0, y: 4, width: 16, height: 14))?.maskWithColor(color: color)
            offset = -3.5
        case DC_STATE_OUT_MDN_RCVD:
            imageAttachment.image = #imageLiteral(resourceName: "ic_done_all_36pt").scaleDownImage(toMax: 16)?.sd_croppedImage(with: CGRect(x: 0, y: 4, width: 16, height: 14))?.maskWithColor(color: color)
            text.append(NSAttributedString(string: "\u{202F}"))
            offset = -3.5
        case DC_STATE_OUT_FAILED:
            imageAttachment.image = #imageLiteral(resourceName: "ic_error_36pt").scaleDownImage(toMax: 14)
        default:
            imageAttachment.image = nil
        }
        let imageString = NSMutableAttributedString(attachment: imageAttachment)
        imageString.addAttributes([.baselineOffset: offset],
                                  range: NSRange(location: 0, length: 1))
        text.append(imageString)
    }

    public static func getFormattedBottomLineAccessibilityString(message: DcMsg) -> String {
        let padlock =  message.showPadlock() ? "\(String.localized("encrypted_message")), " : ""
        let date = "\(message.formattedSentDate()), "
        let sendingState = "\(MessageUtils.getSendingStateString(message.state))"
        return "\(date) \(padlock) \(sendingState)"
    }

    public static func getFormattedSearchResultMessage(messageText: String?, searchText: String?, highlight: Bool) -> NSAttributedString? {
        if let messageText = messageText {
            let fontAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(for: .body, weight: .regular),
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

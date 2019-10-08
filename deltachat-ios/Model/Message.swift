import CoreLocation
import Foundation
import UIKit

struct Message: MessageType {
    var messageId: String
    var sender: SenderType
    var sentDate: Date
    var kind: MessageKind

    init(kind: MessageKind, sender: Sender, messageId: String, date: Date) {
        self.kind = kind
        self.sender = sender
        self.messageId = messageId
        sentDate = date
    }

    init(text: String, sender: Sender, messageId: String, date: Date) {
        self.init(kind: .text(text), sender: sender, messageId: messageId, date: date)
    }

    init(attributedText: NSAttributedString, sender: Sender, messageId: String, date: Date) {
        self.init(kind: .attributedText(attributedText), sender: sender, messageId: messageId, date: date)
    }

    init(image: UIImage, sender: Sender, messageId: String, date: Date) {
        let media = Media(image: image)
        self.init(kind: .photo(media), sender: sender, messageId: messageId, date: date)
    }

    init(thumbnail: UIImage, sender: Sender, messageId: String, date: Date) {
        let url = URL(fileURLWithPath: "")
        let media = Media(url: url, image: thumbnail)
        self.init(kind: .video(media), sender: sender, messageId: messageId, date: date)
    }

    init(location: CLLocation, sender: Sender, messageId: String, date: Date) {
        let locationItem = Location(location: location, size: CGSize(width: 100, height: 50))
        self.init(kind: .location(locationItem), sender: sender, messageId: messageId, date: date)
    }

    init(emoji: String, sender: Sender, messageId: String, date: Date) {
        self.init(kind: .emoji(emoji), sender: sender, messageId: messageId, date: date)
    }
}

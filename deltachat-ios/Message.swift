//
//  Message.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 08.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import CoreLocation
import Foundation
import MessageKit

struct Location: LocationItem {
    var location: CLLocation

    var size: CGSize

    init(location: CLLocation, size: CGSize) {
        self.location = location
        self.size = size
    }
}

struct Media: MediaItem {
    var url: URL?

    var image: UIImage?

    var placeholderImage: UIImage = UIImage(named: "ic_attach_file_36pt")!

    var size: CGSize {
        if let image = image {
            return image.size
        } else {
            return placeholderImage.size
        }
    }

    init(url: URL? = nil, image: UIImage? = nil) {
        self.url = url
        self.image = image
    }
}

struct Message: MessageType {
    var messageId: String
    var sender: Sender
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

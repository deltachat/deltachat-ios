import Foundation
import MobileCoreServices

class ShareAttachment {
    enum AttachmentType {
        case image
        case video
        case audio
        case file
        case text
    }

    var inputItems: [Any]?

    lazy var attachments: [AttachmentType: [NSItemProvider]] = {
       var attachments: [AttachmentType: [NSItemProvider]] = [
           .image: [],
           .video: [],
           .audio: [],
           .file: [],
           .text: []]
       guard let items = inputItems as? [NSExtensionItem] else { return [:] }
       let flatArray = items.flatMap { $0.attachments ?? [] }
       for item in flatArray {
        if item.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
               attachments[.image]?.append(item)
        } else if item.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
               attachments[.video]?.append(item)
           } else if item.hasItemConformingToTypeIdentifier(kUTTypeAudio as String) {
               attachments[.audio]?.append(item)
           } else if item.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
               attachments[.text]?.append(item)
           } else if item.hasItemConformingToTypeIdentifier(kUTTypeContent as String) {
               attachments[.file]?.append(item)
           }
       }
       return attachments
    }()

    lazy var isEmpty: Bool = {
        return attachments[.image]?.isEmpty ?? true &&
            attachments[.video]?.isEmpty ?? true &&
            attachments[.audio]?.isEmpty ?? true &&
            attachments[.file]?.isEmpty ?? true &&
            attachments[.text]?.isEmpty ?? true
    }()

    lazy var video: [NSItemProvider] = {
        return attachments[.video] ?? []
    }()

    lazy var audio: [NSItemProvider] = {
        return attachments[.audio] ?? []
    }()

    lazy var image: [NSItemProvider] = {
        return attachments[.image] ?? []
    }()

    lazy var file: [NSItemProvider] = {
        return attachments[.file] ?? []
    }()

    lazy var text: [NSItemProvider] = {
        return attachments[.text] ?? []
    }()


    init(inputItems: [Any]?) {
        self.inputItems = inputItems
    }

}

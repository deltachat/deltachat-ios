import Foundation
import MobileCoreServices
import DcCore
import UIKit

protocol ShareAttachmentDelegate: class {
    func onAttachmentAdded()
}
class ShareAttachment {

    weak var delegate: ShareAttachmentDelegate?
    let dcContext: DcContext

    var inputItems: [Any]?
    var messages: [DcMsg] = []

    var isEmpty: Bool {
        return messages.isEmpty
    }

    init(dcContext: DcContext, inputItems: [Any]?, delegate: ShareAttachmentDelegate) {
        self.dcContext = dcContext
        self.inputItems = inputItems
        self.delegate = delegate
        createMessages()
    }


    func createMessages() {
        guard let items = inputItems as? [NSExtensionItem] else { return }
        for item in items {
            if let attachments = item.attachments {
                createMessageFromDataRepresentaion(attachments)
            }
        }
    }

    // a NSExtensionItem can have multiple attachments representing the same data in diffent types
    // we want only one DcMsg per NSExtensionItem which is why we're breaking out of the loop
    // after the first match
    func createMessageFromDataRepresentaion(_ attachments: [NSItemProvider]) {
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                createImageMsg(attachment)
                break
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
                createMoviewMsg(attachment)
                break
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeAudio as String) {
                createAudioMsg(attachment)
                break
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
                createFileMsg(attachment)
                break
            }
        }
    }

    func createImageMsg(_ item: NSItemProvider) {
        item.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { data, error in
            let result: UIImage?
            switch data {
            case let image as UIImage:
                result = image
            case let data as Data:
                result = UIImage(data: data)
            case let url as URL:
                result = UIImage(contentsOfFile: url.path)
            default:
                self.dcContext.logger?.debug("Unexpected data: \(type(of: data))")
                result = nil
            }
            if let result = result, let compressedImage = result.dcCompress() {
                let pixelSize = compressedImage.imageSizeInPixel()
                let path = DcUtils.saveImage(image: compressedImage)
                let msg = DcMsg(viewType: DC_MSG_IMAGE)
                msg.setFile(filepath: path, mimeType: "image/jpeg")
                msg.setDimension(width: pixelSize.width, height: pixelSize.height)
                self.messages.append(msg)
                self.delegate?.onAttachmentAdded()
            }
        }
    }

    func createMoviewMsg(_ item: NSItemProvider) {
         createDcMsgFromURL(item: item, typeIdentifier: kUTTypeMovie, viewType: DC_MSG_VIDEO)
    }

    func createAudioMsg(_ item: NSItemProvider) {
        createDcMsgFromURL(item: item, typeIdentifier: kUTTypeAudio, viewType: DC_MSG_AUDIO)
    }

    func createFileMsg(_ item: NSItemProvider) {
        createDcMsgFromURL(item: item, typeIdentifier: kUTTypeFileURL, viewType: DC_MSG_FILE)
    }

    func createDcMsgFromURL(item: NSItemProvider, typeIdentifier: CFString, viewType: Int32) {
        item.loadItem(forTypeIdentifier: typeIdentifier as String, options: nil) { data, error in
            switch data {
            case let url as URL:
                let msg = DcMsg(viewType: viewType)
                msg.setFile(filepath: url.path, mimeType: DcUtils.getMimeTypeForPath(path: url.path))
                self.messages.append(msg)
                self.delegate?.onAttachmentAdded()
            default:
                self.dcContext.logger?.debug("Unexpected data: \(type(of: data))")
            }
        }
    }
}

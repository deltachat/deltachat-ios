import Foundation
import MobileCoreServices
import DcCore
import UIKit
import QuickLookThumbnailing

protocol ShareAttachmentDelegate: class {
    func onAttachmentChanged()
    func onThumbnailChanged()
}

class ShareAttachment {

    weak var delegate: ShareAttachmentDelegate?
    let dcContext: DcContext
    let thumbnailSize = CGFloat(96)

    var inputItems: [Any]?
    var messages: [DcMsg] = []

    private var imageThumbnail: UIImage?
    private var attachmentThumbnail: UIImage?

    var thumbnail: UIImage? {
        return self.imageThumbnail ?? self.attachmentThumbnail
    }

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

    func createMessageFromDataRepresentaion(_ attachments: [NSItemProvider]) {
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                createImageMsg(attachment)
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
                createMovieMsg(attachment)
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeAudio as String) {
                createAudioMsg(attachment)
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
                createFileMsg(attachment)
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
                self.delegate?.onAttachmentChanged()
                self.messages.append(msg)
                if self.imageThumbnail == nil {
                    self.imageThumbnail = compressedImage.scaleDownImage(toMax: self.thumbnailSize)
                    self.delegate?.onThumbnailChanged()
                }
            }
            if error != nil {
                self.dcContext.logger?.error(error?.localizedDescription ?? "Could not load share item as image")
            }
        }
    }

    func createMovieMsg(_ item: NSItemProvider) {
        item.loadItem(forTypeIdentifier: kUTTypeMovie as String, options: nil) { data, error in
            switch data {
            case let url as URL:
                self.addDcMsg(url: url, viewType: DC_MSG_VIDEO)
                self.delegate?.onAttachmentChanged()
                if self.imageThumbnail == nil {
                    self.imageThumbnail = DcUtils.generateThumbnailFromVideo(url: url)?.scaleDownImage(toMax: self.thumbnailSize)
                    self.delegate?.onThumbnailChanged()
                }
            default:
                self.dcContext.logger?.debug("Unexpected data: \(type(of: data))")
            }
            if error != nil {
                self.dcContext.logger?.error(error?.localizedDescription ?? "Could not load share item as video")
            }
        }
    }

    func createAudioMsg(_ item: NSItemProvider) {
        createMessageFromItemURL(item: item, typeIdentifier: kUTTypeAudio, viewType: DC_MSG_AUDIO)
    }

    func createFileMsg(_ item: NSItemProvider) {
        createMessageFromItemURL(item: item, typeIdentifier: kUTTypeFileURL, viewType: DC_MSG_FILE)
    }

    func createMessageFromItemURL(item: NSItemProvider, typeIdentifier: CFString, viewType: Int32) {
        item.loadItem(forTypeIdentifier: typeIdentifier as String, options: nil) { data, error in
            switch data {
            case let url as URL:
                self.addDcMsg(url: url, viewType: viewType)
                self.delegate?.onAttachmentChanged()
                if self.imageThumbnail == nil {
                    self.generateThumbnailRepresentations(url: url)
                }
            default:
                self.dcContext.logger?.debug("Unexpected data: \(type(of: data))")
            }
            if error != nil {
                self.dcContext.logger?.error(error?.localizedDescription ?? "Could not load share item.")
            }
        }
    }

    func addDcMsg(url: URL, viewType: Int32) {
        let msg = DcMsg(viewType: DC_MSG_VIDEO)
        msg.setFile(filepath: url.path, mimeType: DcUtils.getMimeTypeForPath(path: url.path))
        self.messages.append(msg)
    }

    func generateThumbnailRepresentations(url: URL) {
        let size: CGSize = CGSize(width: self.thumbnailSize * 2 / 3, height: self.thumbnailSize)
        let scale = UIScreen.main.scale

        if #available(iOSApplicationExtension 13.0, *) {
            let request = QLThumbnailGenerator.Request(fileAt: url,
                                                       size: size,
                                                       scale: scale,
                                                       representationTypes: .all)
            let generator = QLThumbnailGenerator.shared
            generator.generateRepresentations(for: request) { (thumbnail, _, error) in
                DispatchQueue.main.async {
                    if thumbnail == nil || error != nil {
                        self.dcContext.logger?.warning(error?.localizedDescription ?? "Could not create thumbnail.")
                    } else {
                        self.attachmentThumbnail = thumbnail?.uiImage
                        self.delegate?.onThumbnailChanged()
                    }
                }
            }
        } else {
            let controller = UIDocumentInteractionController(url: url)
            self.attachmentThumbnail = controller.icons.first
            self.delegate?.onThumbnailChanged()
        }
    }

}

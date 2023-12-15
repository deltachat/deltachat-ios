import Foundation
import MobileCoreServices
import DcCore
import UIKit
import QuickLookThumbnailing
import SDWebImage

protocol ShareAttachmentDelegate: class {
    func onAttachmentChanged()
    func onThumbnailChanged()
    func onUrlShared(url: URL)
    func onLoadingStarted()
    func onLoadingFinished()
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


    private func createMessages() {
        guard let items = inputItems as? [NSExtensionItem] else { return }
        delegate?.onLoadingStarted()
        for item in items {
            if let attachments = item.attachments {
                createMessageFromDataRepresentation(attachments)
            }
        }
        delegate?.onLoadingFinished()
    }

    private func createMessageFromDataRepresentation(_ attachments: [NSItemProvider]) {
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(kUTTypeGIF as String) {
                createAnimatedImageMsg(attachment)
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                createImageMsg(attachment)
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
                createMovieMsg(attachment)
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeAudio as String) {
                createAudioMsg(attachment)
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
                createFileMsg(attachment)
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                addSharedUrl(attachment)
            }
        }
    }

    // for now we only support GIF
    private func createAnimatedImageMsg(_ item: NSItemProvider) {
        item.loadItem(forTypeIdentifier: kUTTypeGIF as String, options: nil) { data, error in
            var result: SDAnimatedImage?
            switch data {
            case let animatedImageData as Data:
                result = SDAnimatedImage(data: animatedImageData)
            case let url as URL:
                result = SDAnimatedImage(contentsOfFile: url.path)
            default:
                logger.error("Unexpected data: \(type(of: data))")
            }
            if let result = result {
                let path = ImageFormat.saveImage(image: result, directory: .cachesDirectory)
                let msg = self.dcContext.newMessage(viewType: DC_MSG_GIF)
                msg.setFile(filepath: path)
                self.messages.append(msg)
                self.delegate?.onAttachmentChanged()
                if self.imageThumbnail == nil {
                    self.imageThumbnail = result
                    self.delegate?.onThumbnailChanged()
                }
                if let error = error {
                    logger.error("Could not load share item as image: \(error.localizedDescription)")
                }
            }
        }
    }

    private func createImageMsg(_ item: NSItemProvider) {
        item.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { data, error in
            var result: UIImage?
            switch data {
            case let image as UIImage:
                result = image
            case let data as Data:
                result = ImageFormat.loadImageFrom(data: data)
            case let url as URL:
                result = ImageFormat.loadImageFrom(url: url)
            default:
                logger.error("Unexpected data: \(type(of: data))")
            }
            if let result = result,
               let path = ImageFormat.saveImage(image: result, directory: .cachesDirectory) {
                let msg = self.dcContext.newMessage(viewType: DC_MSG_IMAGE)
                msg.setFile(filepath: path)
                self.messages.append(msg)
                self.delegate?.onAttachmentChanged()
                if self.imageThumbnail == nil {
                    self.imageThumbnail = ImageFormat.scaleDownImage(NSURL(fileURLWithPath: path), toMax: self.thumbnailSize)
                    self.delegate?.onThumbnailChanged()
                }
            }
            if let error = error {
                logger.error("Could not load share item as image: \(error.localizedDescription)")
            }
        }
    }

    private func createMovieMsg(_ item: NSItemProvider) {
        item.loadItem(forTypeIdentifier: kUTTypeMovie as String, options: nil) { data, error in
            switch data {
            case let url as URL:
                _ = self.addDcMsg(url: url, viewType: DC_MSG_VIDEO)
                self.delegate?.onAttachmentChanged()
                if self.imageThumbnail == nil {
                    DispatchQueue.global(qos: .background).async {
                        self.imageThumbnail = DcUtils.generateThumbnailFromVideo(url: url)
                        DispatchQueue.main.async {
                            self.delegate?.onThumbnailChanged()
                        }
                    }

                }
            default:
                logger.error("Unexpected data: \(type(of: data))")
            }
            if let error = error {
                logger.error("Could not load share item as video: \(error.localizedDescription)")
            }
        }
    }

    private func createAudioMsg(_ item: NSItemProvider) {
        createMessageFromItemURL(item: item, typeIdentifier: kUTTypeAudio, viewType: DC_MSG_AUDIO)
    }

    private func createFileMsg(_ item: NSItemProvider) {
        createMessageFromItemURL(item: item, typeIdentifier: kUTTypeFileURL, viewType: DC_MSG_FILE)
    }

    private func createMessageFromItemURL(item: NSItemProvider, typeIdentifier: CFString, viewType: Int32) {
        item.loadItem(forTypeIdentifier: typeIdentifier as String, options: nil) { data, error in
            switch data {
            case let url as URL:
                if url.pathExtension == "xdc" {
                    let webxdcMsg = self.addDcMsg(url: url, viewType: DC_MSG_WEBXDC)
                    if self.imageThumbnail == nil {
                        self.imageThumbnail = webxdcMsg.getWebxdcPreviewImage()?
                            .scaleDownImage(toMax: self.thumbnailSize,
                                            cornerRadius: 10)
                        self.delegate?.onThumbnailChanged()
                    }
                } else {
                    _ = self.addDcMsg(url: url, viewType: viewType)
                }
                self.delegate?.onAttachmentChanged()
                if self.imageThumbnail == nil {
                    self.generateThumbnailRepresentations(url: url)
                }
            default:
                logger.error("Unexpected data: \(type(of: data))")
            }
            if let error = error {
                logger.error("Could not load share item: \(error.localizedDescription)")
            }
        }
    }

    private func addDcMsg(url: URL, viewType: Int32) -> DcMsg {
        let msg = dcContext.newMessage(viewType: viewType)
        msg.setFile(filepath: url.relativePath)
        self.messages.append(msg)
        return msg
    }

    private func generateThumbnailRepresentations(url: URL) {
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
                        logger.warning(error?.localizedDescription ?? "Could not create thumbnail.")
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

    private func addSharedUrl(_ item: NSItemProvider) {
        if let delegate = self.delegate {
            item.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { data, error in
                switch data {
                case let url as URL:
                    delegate.onUrlShared(url: url)
                default:
                    logger.error("Unexpected data: \(type(of: data))")
                }
                if let error = error {
                    logger.error("Could not share URL: \(error.localizedDescription)")
                }
            }
        }
    }
}

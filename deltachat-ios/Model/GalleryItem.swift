import UIKit
import DcCore
import SDWebImage

class GalleryItem: ContextMenuItem {

    var onImageLoaded: ((UIImage?) -> Void)?

    var msg: DcMsg

    var fileUrl: URL? {
        return msg.fileURL
    }

    var description: String?

    var thumbnailImage: UIImage? {
        get {
            if let fileUrl = self.fileUrl {
                if let image = ThumbnailCache.shared.restoreImage(key: fileUrl.absoluteString) {
                    return image
                } else {
                    loadThumbnail()
                }
            }
            return nil
        }
        set {
            if let fileUrl = self.fileUrl {
                if let image = newValue {
                    ThumbnailCache.shared.storeImage(image: image, key: fileUrl.absoluteString)
                    onImageLoaded?(newValue)
                } else {
                    ThumbnailCache.shared.deleteImage(key: fileUrl.absoluteString)
                }
            }
        }
    }

    var showPlayButton: Bool {
        switch msg.viewtype {
        case .video:
            return true
        default:
            return false
        }
    }

    init(msg: DcMsg) {
        self.msg = msg
        if let key = msg.fileURL?.absoluteString, let image = ThumbnailCache.shared.restoreImage(key: key) {
            self.thumbnailImage = image
        } else {
            loadThumbnail()
        }
        if msg.viewtype == .webxdc {
            description = msg.getWebxdcInfoDict()["name"] as? String ?? "ErrName"
        }
    }

    private func loadThumbnail() {
        guard let viewtype = msg.viewtype, let url = msg.fileURL else {
            return
        }
        switch viewtype {
        case .image, .gif:
            loadImageThumbnail(from: url)
        case .video:
            loadVideoThumbnail(from: url)
        case .webxdc:
            loadWebxdcThumbnail(from: msg)
        default:
            return
        }
    }

    private func loadImageThumbnail(from url: URL) {
        DispatchQueue.global(qos: .userInteractive).async {
            if let image = ImageFormat.loadImageFrom(url: url) {
                DispatchQueue.main.async { [weak self] in
                    self?.thumbnailImage = image
                }
            } else {
                logger.error("cannot load image thumbnail for \(url)")
            }
        }
    }

    private func loadVideoThumbnail(from url: URL) {
        DispatchQueue.global(qos: .userInteractive).async {
            if let image = DcUtils.generateThumbnailFromVideo(url: url) {
                DispatchQueue.main.async { [weak self] in
                    self?.thumbnailImage = image
                }
            } else {
                logger.error("cannot load video thumbnail for \(url)")
            }
        }
    }

    private func loadWebxdcThumbnail(from message: DcMsg) {
        DispatchQueue.global(qos: .userInteractive).async {
            if let image = message.getWebxdcPreviewImage() {
                DispatchQueue.main.async { [weak self] in
                    self?.thumbnailImage = image
                }
            } else {
                logger.error("cannot load webxdc thumbnail for \(message.file ?? "ErrName")")
            }
        }
    }
}

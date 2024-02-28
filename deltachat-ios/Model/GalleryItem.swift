import UIKit
import DcCore
import SDWebImage

class GalleryItem {

    var onImageLoaded: ((UIImage?) -> Void)?

    let msg: DcMsg

    var thumbnailImage: UIImage? {
        get {
            loadThumbnail()
            return nil
        }
        set {
            onImageLoaded?(newValue)
        }
    }

    init(msg: DcMsg) {
        self.msg = msg
        loadThumbnail()
    }

    private func loadThumbnail() {
        guard let url = msg.fileURL else { return }
        switch msg.type {
        case DC_MSG_IMAGE, DC_MSG_STICKER, DC_MSG_GIF:
            loadImageThumbnail(from: url)
        case DC_MSG_VIDEO:
            loadVideoThumbnail(from: url)
        case DC_MSG_WEBXDC:
            loadWebxdcThumbnail(from: msg)
        default:
            return
        }
    }

    private func loadImageThumbnail(from url: URL) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            if let image = ImageFormat.loadImageFrom(url: url) {
                DispatchQueue.main.async { [weak self] in
                    self?.thumbnailImage = image
                }
            } else {
                logger.warning("cannot load image thumbnail for \(url)")
                self?.setLoadingFailedPlaceholder()
            }
        }
    }

    private func loadVideoThumbnail(from url: URL) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            if let image = DcUtils.generateThumbnailFromVideo(url: url) {
                DispatchQueue.main.async { [weak self] in
                    self?.thumbnailImage = image
                }
            } else {
                logger.warning("cannot load video thumbnail for \(url)")
                self?.setLoadingFailedPlaceholder()
            }
        }
    }

    private func loadWebxdcThumbnail(from message: DcMsg) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            if let image = message.getWebxdcPreviewImage() {
                DispatchQueue.main.async { [weak self] in
                    self?.thumbnailImage = image
                }
            } else {
                logger.warning("cannot load webxdc thumbnail for \(message.file ?? "ErrName")")
                self?.setLoadingFailedPlaceholder()
            }
        }
    }

    private func setLoadingFailedPlaceholder() {
        DispatchQueue.main.async { [weak self] in
            self?.thumbnailImage = UIImage(named: "ic_error_36pt")?.sd_tintedImage(with: .gray)
        }
    }
}

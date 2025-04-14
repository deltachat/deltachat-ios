import SDWebImage
import UIKit
import UniformTypeIdentifiers

extension UIPasteboard {
    /// Also returns true for webp
    public var hasImagesExtended: Bool {
        hasImages || types.contains(UTType.webP.identifier)
    }

    /// Also supports gif and webp using SDAnimatedImage and SDWebImage
    public var imageExtended: UIImage? {
        gif ?? image ?? webp
    }

    private var gif: SDAnimatedImage? {
        data(forPasteboardType: UTType.gif.identifier).flatMap(SDAnimatedImage.init(data:))
    }

    private var webp: UIImage? {
        data(forPasteboardType: UTType.webP.identifier).flatMap(UIImage.sd_image(withWebPData:))
    }
}

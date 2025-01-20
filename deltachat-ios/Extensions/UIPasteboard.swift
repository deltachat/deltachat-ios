import SDWebImage
import UIKit
import UniformTypeIdentifiers

extension UIPasteboard {
    /// Also returns true for webp
    public var hasImagesExtended: Bool {
        return hasImages || types.contains(UTType.webP.identifier)
    }

    /// Also returns webp image
    public var imageExtended: UIImage? {
        return image ?? UIImage.sd_image(withWebPData: data(forPasteboardType: UTType.webP.identifier))
    }
}

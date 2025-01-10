import SDWebImage
import UIKit
import UniformTypeIdentifiers

extension UIPasteboard {
    /// Also returns true for webp (on iOS 14+)
    public var hasImagesExtended: Bool {
        guard #available(iOS 14.0, *) else { return hasImages }
        return hasImages || types.contains(UTType.webP.identifier)
    }

    /// Also returns webp image (on iOS 14+)
    public var imageExtended: UIImage? {
        guard #available(iOS 14.0, *) else { return image }
        return image ?? UIImage.sd_image(withWebPData: data(forPasteboardType: UTType.webP.identifier))
    }
}

import UIKit
import UniformTypeIdentifiers

extension NSItemProvider {
    /// Load image prefering WebP (to prevent transparency loss) and falling back on `UIImage.sd_image(with:)` using raw data.
    public func loadImage(completionHandler: @escaping (UIImage?, (any Error)?) -> Void) {
        // If webP is provided and eg JPEG (or another type that is supported by loadObject),
        // always pick webP because it might have transparancy unlike JPEG.
        if hasItemConformingToTypeIdentifier(UTType.webP.identifier) {
            loadDataRepresentation(forTypeIdentifier: UTType.webP.identifier) { webPData, error in
                completionHandler(UIImage.sd_image(withWebPData: webPData), error)
            }
        } else if canLoadObject(ofClass: UIImage.self) {
            loadObject(ofClass: UIImage.self) { imageItem, error in
                completionHandler(imageItem as? UIImage, error)
            }
        } else {
            // Some images (like webP) can't be loaded into UIImage by UIDropSession so we fall back on SD.
            // See `UIImage.readableTypeIdentifiersForItemProvider` for ones that can.
            loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                completionHandler(UIImage.sd_image(with: data), error)
            }
        }
    }
}

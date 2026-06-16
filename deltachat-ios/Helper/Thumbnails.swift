import AVFoundation
import DcCore
import SDWebImage

extension DcUtils {
    public static func generateThumbnailFromVideo(url: URL?) -> UIImage? {
        guard let url = url else { return nil }
        do {
            if let image = cachedThumbnail(for: url) {
                return image
            }
            let asset = AVURLAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            cacheThumbnail(image, for: url)
            return image
        } catch {
            logger.error(error.localizedDescription)
            return nil
        }
    }

    public static func thumbnailFromPdf(withUrl url: URL, pageNumber: Int = 1, width: CGFloat = 240) -> UIImage? {
        if let image = cachedThumbnail(for: url) {
            return image
        }
        guard let pdf = CGPDFDocument(url as CFURL),
              let page = pdf.page(at: pageNumber)
        else {
            return nil
        }

        var pageRect = page.getBoxRect(.mediaBox)
        let pdfScale = width / pageRect.size.width
        pageRect.size = CGSize(width: pageRect.size.width*pdfScale, height: pageRect.size.height*pdfScale)
        pageRect.origin = .zero

        UIGraphicsBeginImageContext(pageRect.size)
        let context = UIGraphicsGetCurrentContext()!

        // White BG
        context.setFillColor(UIColor.white.cgColor)
        context.fill(pageRect)
        context.saveGState()

        // Next 3 lines makes the rotations so that the page look in the right direction
        context.translateBy(x: 0.0, y: pageRect.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.concatenate(page.getDrawingTransform(.mediaBox, rect: pageRect, rotate: 0, preserveAspectRatio: true))

        context.drawPDFPage(page)
        context.restoreGState()

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        cacheThumbnail(image, for: url)
        return image
    }

    private static func cachedThumbnail(for url: URL) -> UIImage? {
        SDImageCache.shared.imageFromCache(forKey: url.absoluteString + "-thumbnail")
    }

    private static func cacheThumbnail(_ thumbnail: UIImage?, for url: URL) {
        SDImageCache.shared.store(thumbnail, forKey: url.absoluteString + "-thumbnail")
    }
}

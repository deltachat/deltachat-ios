import UIKit

public extension UIImage {

    private func getResizedRectangle(toMax: Float) -> CGRect {
        var actualHeight = Float(size.height)
        var actualWidth = Float(size.width)
        let maxHeight: Float = toMax
        let maxWidth: Float = toMax
        var imgRatio: Float = actualWidth / actualHeight
        let maxRatio: Float = maxWidth / maxHeight
        if actualHeight > maxHeight || actualWidth > maxWidth {
            if imgRatio < maxRatio {
                // adjust width according to maxHeight
                imgRatio = maxHeight / actualHeight
                actualWidth = imgRatio * actualWidth
                actualHeight = maxHeight
            } else if imgRatio > maxRatio {
                // adjust height according to maxWidth
                imgRatio = maxWidth / actualWidth
                actualHeight = imgRatio * actualHeight
                actualWidth = maxWidth
            } else {
                actualHeight = maxHeight
                actualWidth = maxWidth
            }
        }
        return CGRect(x: 0.0, y: 0.0, width: CGFloat(actualWidth), height: CGFloat(actualHeight))
    }

    func scaleDownImage(toMax: CGFloat, cornerRadius: CGFloat? = nil) -> UIImage? {
        let rect = getResizedRectangle(toMax: Float(toMax))
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        if let cornerRadius = cornerRadius {
            UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
        }

        draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }

    func imageSizeInPixel() -> CGSize {
        let heightInPoints = size.height
        let heightInPixels = heightInPoints * scale
        let widthInPoints = size.width
        let widthInPixels = widthInPoints * scale
        return CGSize(width: widthInPixels, height: heightInPixels)
    }

    func isTransparent() -> Bool {
        guard let alpha: CGImageAlphaInfo = self.cgImage?.alphaInfo else { return false }
        return alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast
    }

    var hasStickerLikeProperties: Bool {
        let preiOS18StickerSize = CGSize(width: 140, height: 140)
        let iOS18StickerSize = CGSize(width: 160, height: 160)
        if size.equalTo(preiOS18StickerSize) || size.equalTo(iOS18StickerSize) {
            return true
        }

        if !self.isTransparent() {
            return false
        }

        guard let cgImage else { return false }

        // https://christianselig.com/2021/04/efficient-average-color/
        // First, resize the image. We do this for two reasons, 1) less pixels to deal with means faster calculation and a resized image still has the "gist" of the colors, and 2) the image we're dealing with may come in any of a variety of color formats (CMYK, ARGB, RGBA, etc.) which complicates things, and redrawing it normalizes that into a base color format we can deal with.
        // 40x40 is a good size to resize to still preserve quite a bit of detail but not have too many pixels to deal with. Aspect ratio is irrelevant for just finding average color.
        let size = CGSize(width: 40, height: 40)

        let width = Int(size.width)
        let height = Int(size.height)
        let totalPixels = width * height

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // ARGB format
        let bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

        // 8 bits for each color channel, we're doing ARGB so 32 bits (4 bytes) total, and thus if the image is n pixels wide, and has 4 bytes per pixel, the total bytes per row is 4n. That gives us 2^8 = 256 color variations for each RGB channel or 256 * 256 * 256 = ~16.7M color options in total. That seems like a lot, but lots of HDR movies are in 10 bit, which is (2^10)^3 = 1 billion color options!
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo) else { return false }

        // Draw our resized image
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        guard let pixelBuffer = context.data else { return false }

        // Bind the pixel buffer's memory location to a pointer we can use/access
        let pointer = pixelBuffer.bindMemory(to: UInt32.self, capacity: width * height)

        // Keep track of total fully transparent pixes
        var totalFullyTransparentPixels = 0

        for x in 0 ..< width {
            for y in 0 ..< height {
                let pixel = pointer[(y * width) + x]
                if alpha(for: pixel) == 0 {
                    totalFullyTransparentPixels += 1
                }
            }
        }

        // More than 10% transparent, probably a sticker
        return CGFloat(totalFullyTransparentPixels) / CGFloat(totalPixels) > 0.1
    }

    private func alpha(for pixel: UInt32) -> UInt8 {
        return UInt8((pixel >> 24) & 255)
    }
}

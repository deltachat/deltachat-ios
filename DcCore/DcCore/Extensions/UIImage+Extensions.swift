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

}

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
    
    func hasTransparentCorner() -> Bool {
        if !self.isTransparent() {
            return false
        }
        guard let cgImage = self.cgImage,
              let data = cgImage.dataProvider?.data as Data?,
              let dataPtr = data.withUnsafeBytes({ $0.bindMemory(to: UInt8.self).baseAddress }),
              !data.isEmpty else {
            return false // Unable to get the CGImage or image data
        }
    
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        
        // Check the alpha values of the pixels at the corners
        let topLeftIndex = 0
        let topRightIndex = max(0, width - 1)
        let bottomLeftIndex = max(0, bytesPerRow * (height - 1))
        let bottomRightIndex = max(0, bytesPerRow * (height - 1) + width - 1)

        var hasTransparentCorner = false
        if dataPtr[topLeftIndex] < 255 {
            hasTransparentCorner = true
        } else if dataPtr[topRightIndex] < 255 {
            hasTransparentCorner = true
        } else if dataPtr[bottomLeftIndex] < 255 {
            hasTransparentCorner = true
        } else if dataPtr[min(data.count - 1, bottomRightIndex)] < 255 {
            hasTransparentCorner = true
        }

        return hasTransparentCorner
    }
    
}

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
                //adjust width according to maxHeight
                imgRatio = maxHeight / actualHeight
                actualWidth = imgRatio * actualWidth
                actualHeight = maxHeight
            } else if imgRatio > maxRatio {
                //adjust height according to maxWidth
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

    func scaleDownImage(toMax: CGFloat) -> UIImage? {
        let rect = getResizedRectangle(toMax: Float(toMax))
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }

    public func dcCompress(toMax target: Float = 1280) -> UIImage? {
        return scaleDownAndCompress(toMax: target)
    }

    public func imageSizeInPixel() -> CGSize {
        let heightInPoints = size.height
        let heightInPixels = heightInPoints * scale
        let widthInPoints = size.width
        let widthInPixels = widthInPoints * scale
        return CGSize(width: widthInPixels, height: heightInPixels)
    }
    
    // if an image has an alpha channel we try to keep it, using PNG formatting instead of JPEG
    // PNGs are less compressed than JPEGs - to keep the message sizes small,
    // the size of PNG imgaes will be scaled down
    public func scaleDownAndCompress(toMax: Float) -> UIImage? {
        let rect = getResizedRectangle(toMax: self.isTransparent() ?
            min(Float(self.size.width) / 2, toMax / 2) :
            toMax)

        UIGraphicsBeginImageContextWithOptions(rect.size, !self.isTransparent(), 0.0)
        draw(in: rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()

        let imageData = self.isTransparent() ?
            img?.pngData() :
            img?.jpegData(compressionQuality: 0.85)

        UIGraphicsEndImageContext()
        return UIImage(data: imageData!)
    }

    func isTransparent() -> Bool {
      guard let alpha: CGImageAlphaInfo = self.cgImage?.alphaInfo else { return false }
      return alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast
    }

}

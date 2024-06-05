import UIKit
import DcCore

extension UIImage {

    func maskWithColor(color: UIColor) -> UIImage? {
        let maskImage = cgImage!

        let width = size.width
        let height = size.height
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(
            data: nil,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )!
        context.clip(to: bounds, mask: maskImage)
        context.setFillColor(color.cgColor)
        context.fill(bounds)

        if let cgImage = context.makeImage() {
            let coloredImage = UIImage(cgImage: cgImage)
            return coloredImage
        } else {
            return nil
        }
    }

    public convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }

    public func generateSplash(backgroundColor: UIColor, isPortrait: Bool) -> UIImage? {
        let rect: CGRect
        if isPortrait {
            rect = CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width,
                                                          height: UIScreen.main.bounds.height))
        } else {
            rect = CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.height,
                                                          height: UIScreen.main.bounds.width))
        }

        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        backgroundColor.setFill()
        UIRectFill(rect)
        let horizontalPadding = (rect.width - self.size.width) / 2
        let verticalPadding = (rect.height - self.size.height) / 2 + UIApplication.shared.statusBarFrame.height
        self.draw(in: CGRect(horizontalPadding, verticalPadding, self.size.width, self.size.height))
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return finalImage
    }
}

extension UIImage {
    public static func fromBase64(string: String) -> UIImage? {
        guard let imageData = Data(base64Encoded: string) else { return nil }

        return UIImage(data: imageData)
    }
}

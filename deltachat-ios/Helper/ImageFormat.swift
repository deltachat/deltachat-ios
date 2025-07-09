import Foundation
import UIKit
import SDWebImage
import DcCore

extension ImageFormat {

    static func loadImageFrom(data: Data) -> UIImage? {
        if let image = SDAnimatedImage(data: data) {
            return image
        }
        // use UIImage if SDAnimatedImage failes (known for some JPG, see #1911, SDAnimatedImageView does probably sth. similar)
        return UIImage(data: data)
    }

    static func loadImageFrom(url: URL) -> UIImage? {
        guard let imageData = try? Data(contentsOf: url) else {
            return nil
        }
        return loadImageFrom(data: imageData)
    }

    public static func saveImage(image: UIImage, name: String? = nil, directory: FileManager.SearchPathDirectory = .applicationSupportDirectory) -> String? {
        if image.sd_isAnimated,
           let data = image.sd_imageData(),
           let format = ImageFormat.get(from: data) {
            return FileHelper.saveData(data: data, name: name, suffix: format.rawValue, directory: directory)
        }
        let suffix = image.isTransparent() ? "png" : "jpg"
        guard let data = image.isTransparent() ? image.pngData() : image.jpegData(compressionQuality: 1.0) else {
            return nil
        }

        return FileHelper.saveData(data: data, name: name, suffix: suffix)
    }

    // This scaling method is more memory efficient than UIImage.scaleDownImage(toMax: CGFloat)
    // but requires an NSURL as parameter
    public static func scaleDownImage(_ url: NSURL, toMax: CGFloat) -> UIImage? {
        let imgSource = CGImageSourceCreateWithURL(url, nil)
        guard let imageSource = imgSource else {
            return nil
        }

        var scaledImage: CGImage?
        let options: [NSString: Any] = [
            // The maximum width and height in pixels of a thumbnail.
            kCGImageSourceThumbnailMaxPixelSize: toMax,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Should include kCGImageSourceCreateThumbnailWithTransform: true in the options dictionary. Otherwise, the image result will appear rotated when an image is taken from camera in the portrait orientation.
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        scaledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
        if let scaledImage = scaledImage {
            return UIImage(cgImage: scaledImage)
        }
        return nil
    }
}

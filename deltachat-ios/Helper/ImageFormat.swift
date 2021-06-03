import Foundation
import UIKit
import SDWebImage
import DcCore

enum ImageFormat: String {
    case png, jpg, gif, tiff, webp, heic, bmp, unknown
}

extension ImageFormat {

    // magic bytes can be found here: https://en.wikipedia.org/wiki/List_of_file_signatures
    static func get(from data: Data) -> ImageFormat {
        switch data[0] {
        case 0x89:
            return .png
        case 0xFF:
            return .jpg
        case 0x47:
            return .gif
        case 0x49, 0x4D:
            return .tiff
        case 0x52 where data.count >= 12:
            let subdata = data[0...11]

            if let dataString = String(data: subdata, encoding: .ascii),
                dataString.hasPrefix("RIFF"),
                dataString.hasSuffix("WEBP") {
                return .webp
            }

        case 0x00 where data.count >= 12 :
            let subdata = data[8...11]

            if let dataString = String(data: subdata, encoding: .ascii),
                Set(["heic", "heix", "hevc", "hevx"]).contains(dataString) {
                return .heic
            }

        case 0x42 where data.count >= 2 :
            if data[1] == 0x4D {
                return .bmp
            }

        default:
            break
        }
        return .unknown
    }


    // Theoretically, SDAnimatedImage should be able to read data of all kinds of images.
    // In practive, JPG files haven't been read correctly, for now we're using SDAnimatedImage
    // only for file formats that support animated content.
    static func loadImageFrom(data: Data) -> UIImage? {
        switch ImageFormat.get(from: data) {
        case .gif, .png, .webp, .heic:
            return SDAnimatedImage(data: data)
        default:
            return UIImage(data: data)
        }
    }

    static func loadImageFrom(url: URL) -> UIImage? {
        guard let imageData = try? Data(contentsOf: url) else {
            return nil
        }
        return loadImageFrom(data: imageData)
    }

    public static func saveImage(image: UIImage) -> String? {
        if image.sd_isAnimated,
           let data = image.sd_imageData() {
            let format = ImageFormat.get(from: data)
            if format != .unknown {
                return ImageFormat.saveImage(data: data, suffix: format.rawValue)
            }
        }
        let suffix = image.isTransparent() ? "png" : "jpg"
        guard let data = image.isTransparent() ? image.pngData() : image.jpegData(compressionQuality: 1.0) else {
            return nil
        }

        return saveImage(data: data, suffix: suffix)
    }

    public static func saveImage(data: Data, suffix: String) -> String? {
        let timestamp = Double(Date().timeIntervalSince1970)
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                           appropriateFor: nil, create: false) as NSURL,
            let path = directory.appendingPathComponent("\(timestamp).\(suffix)")
            else { return nil }

        do {
            try data.write(to: path)
            return path.relativePath
        } catch {
            DcContext.shared.logger?.info(error.localizedDescription)
            return nil
        }
    }
}

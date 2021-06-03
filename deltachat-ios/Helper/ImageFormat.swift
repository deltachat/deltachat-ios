import Foundation
import UIKit
import SDWebImage

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

}

public enum ImageFormat: String {
    case png, jpg, gif, tiff, webp, heic, bmp
}

extension ImageFormat {
    /// Returns a recognized image format or nil
    public static func get(from data: Data) -> ImageFormat? {
        // magic bytes can be found here: https://en.wikipedia.org/wiki/List_of_file_signatures
        switch data.first {
        case 0x89:
            return .png
        case 0xFF:
            return .jpg
        case 0x47:
            return .gif
        case 0x49, 0x4D:
            return .tiff
        case 0x52 where data.count >= 12: // R
            if data[1] == 0x49 &&         // I
               data[2] == 0x46 &&         // F
               data[3] == 0x46 &&         // F
               data[8] == 0x57 &&         // W
               data[9] == 0x45 &&         // E
               data[10] == 0x42 &&        // B
               data[11] == 0x50 {         // P
                return .webp
            }
            
        case 0x00 where data.count >= 12:
            let subdata = data[8...11]
            
            if let dataString = String(data: subdata, encoding: .ascii),
               Set(["heic", "heix", "hevc", "hevx"]).contains(dataString) {
                return .heic
            }
            
        case 0x42 where data.count >= 2:
            if data[1] == 0x4D {
                return .bmp
            }
            
        default:
            break
        }
        return nil
    }
}

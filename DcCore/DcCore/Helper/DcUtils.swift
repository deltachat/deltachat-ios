import Foundation
import UIKit
import MobileCoreServices
import AVFoundation

public struct DcUtils {

    public static func getInitials(inputName: String) -> String {
        if let firstLetter = inputName.first {
            return firstLetter.uppercased()
        } else {
            return ""
        }
    }

    static func copyAndFreeArray(inputArray: OpaquePointer?) -> [Int] {
        var acc: [Int] = []
        let len = dc_array_get_cnt(inputArray)
        for i in 0 ..< len {
            let e = dc_array_get_id(inputArray, i)
            acc.append(Int(e))
        }
        dc_array_unref(inputArray)

        return acc
    }

    static func copyAndFreeArrayWithLen(inputArray: OpaquePointer?, len: Int = 0) -> [Int] {
        var acc: [Int] = []
        let arrayLen = dc_array_get_cnt(inputArray)
        let start = max(0, arrayLen - len)
        for i in start ..< arrayLen {
            let e = dc_array_get_id(inputArray, i)
            acc.append(Int(e))
        }
        dc_array_unref(inputArray)

        return acc
    }

    static func copyAndFreeArrayWithOffset(inputArray: OpaquePointer?, len: Int = 0, from: Int = 0, skipEnd: Int = 0) -> [Int] {
        let lenArray = dc_array_get_cnt(inputArray)
        if lenArray <= skipEnd || lenArray == 0 {
            dc_array_unref(inputArray)
            return []
        }

        let start = lenArray - 1 - skipEnd
        let end = max(0, start - len)
        let finalLen = start - end + (len > 0 ? 0 : 1)
        var acc: [Int] = [Int](repeating: 0, count: finalLen)

        for i in stride(from: start, to: end, by: -1) {
            let index = finalLen - (start - i) - 1
            acc[index] = Int(dc_array_get_id(inputArray, i))
        }

        dc_array_unref(inputArray)
        DcContext.shared.logger?.info("got: \(from) \(len) \(lenArray) - \(acc)")

        return acc
    }

    public static func saveImage(image: UIImage) -> String? {
        let timestamp = Double(Date().timeIntervalSince1970)
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                           appropriateFor: nil, create: false) as NSURL,
            let data = image.isTransparent() ? image.pngData() : image.jpegData(compressionQuality: 1.0),
            let path = directory.appendingPathComponent("\(timestamp).jpg")
            else { return nil }

        do {
            try data.write(to: path)
            return path.relativePath
        } catch {
            DcContext.shared.logger?.info(error.localizedDescription)
            return nil
        }
    }

    public static func saveAnimatedImage(data: Data, suffix: String) -> String? {
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

    public static func getMimeTypeForPath(path: String) -> String {
        let url = NSURL(fileURLWithPath: path)
        let pathExtension = url.pathExtension

        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension! as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream"
    }

    public static func generateThumbnailFromVideo(url: URL?) -> UIImage? {
           guard let url = url else {
               return nil
           }
           do {
               let asset = AVURLAsset(url: url)
               let imageGenerator = AVAssetImageGenerator(asset: asset)
               imageGenerator.appliesPreferredTrackTransform = true
               let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
               return UIImage(cgImage: cgImage)
           } catch {
               print(error.localizedDescription)
               return nil
           }
       }

}

import Foundation
import UIKit
import AVFoundation

struct Utils {

    static func getInitials(inputName: String) -> String {
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

/*    static func formatAddressForQuery(address: [String: String]) -> String {
        // Open address in Apple Maps app.
        var addressParts = [String]()
        let addAddressPart: ((String?) -> Void) = { part in
            guard let part = part else {
                return
            }
            guard !part.isEmpty else {
                return
            }
            addressParts.append(part)
        }
        addAddressPart(address["Street"])
        addAddressPart(address["Neighborhood"])
        addAddressPart(address["City"])
        addAddressPart(address["Region"])
        addAddressPart(address["Postcode"])
        addAddressPart(address["Country"])
        return addressParts.joined(separator: ", ")
    }

    // compression needs to be done before in UIImage.dcCompress()
    static func saveImage(image: UIImage) -> String? {
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false) as NSURL else {
            return nil
        }

        guard let data = image.isTransparent() ? image.pngData() : image.jpegData(compressionQuality: 1.0) else {
            return nil
        }

        do {
            let timestamp = Double(Date().timeIntervalSince1970)
            let path = directory.appendingPathComponent("\(timestamp).jpg")
            try data.write(to: path!)
            return path?.relativePath
        } catch {
            logger.info(error.localizedDescription)
            return nil
        }
    }
     */

    static func hasAudioSuffix(url: URL) -> Bool {
        ///TODO: add more file suffixes
        return url.absoluteString.hasSuffix("wav")
    }



    static func generateThumbnailFromVideo(url: URL?) -> UIImage? {
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

    /*
    static func getDeviceLanguage() -> String? {
        // some device languages have suffixes (like en-aus etc.) so we want to cut suffixes off
        guard let lang = Locale.preferredLanguages.first?.split(separator: "-").first else {
            return nil
        }
        return String(lang)
    }
     */
}

class DateUtils {
    typealias DtU = DateUtils
    static let minute: Double = 60
    static let hour: Double = 3600
    static let day: Double = 86400
    static let year: Double = 365 * day

    static func getRelativeTimeInSeconds(timeStamp: Double) -> Double {
        let unixTime = Double(Date().timeIntervalSince1970)
        return unixTime - timeStamp
    }

    private static func is24hDefault() -> Bool {
        let dateString: String = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current) ?? ""
        return !dateString.contains("a")
    }

    private static func getLocalDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = .current
        formatter.locale = .current
        return formatter
    }

    static func getExtendedRelativeTimeSpanString(timeStamp: Double) -> String {
        let seconds = getRelativeTimeInSeconds(timeStamp: timeStamp)
        let date = Date(timeIntervalSince1970: timeStamp)
        let formatter = getLocalDateFormatter()
        let is24h = is24hDefault()

        if seconds < DtU.minute {
            return String.localized("now")
        } else if seconds < DtU.hour {
            let mins = seconds / DtU.minute
            return String.localized(stringID: "n_minutes", count: Int(mins))
        } else if seconds < DtU.day {
            formatter.dateFormat = is24h ?  "HH:mm" : "hh:mm a"
            return formatter.string(from: date)
        } else if seconds < 6 * DtU.day {
            formatter.dateFormat = is24h ?  "EEE, HH:mm" : "EEE, hh:mm a"
            return formatter.string(from: date)
        } else if seconds < DtU.year {
            formatter.dateFormat = is24h ? "MMM d, HH:mm" : "MMM d, hh:mm a"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = is24h ? "MMM d, yyyy, HH:mm" : "MMM d, yyyy, hh:mm a"
            return formatter.string(from: date)
        }
    }

    static func getBriefRelativeTimeSpanString(timeStamp: Double) -> String {
        let seconds = getRelativeTimeInSeconds(timeStamp: timeStamp)
        let date = Date(timeIntervalSince1970: timeStamp)
        let formatter = getLocalDateFormatter()

        if seconds < DtU.minute {
            return String.localized("now")	// under one minute
        } else if seconds < DtU.hour {
            let mins = seconds / DtU.minute
            return String.localized(stringID: "n_minutes", count: Int(mins))
        } else if seconds < DtU.day {
            let hours = seconds / DtU.hour
            return String.localized(stringID: "n_hours", count: Int(hours))
        } else if seconds < DtU.day * 6 {
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        } else if seconds < DtU.year {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            let localDate = formatter.string(from: date)
            return localDate
        }
    }

}

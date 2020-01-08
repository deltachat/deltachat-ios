import Foundation
import UIKit
import AVFoundation

struct Utils {

    // do not use, use DcContext::getContacts() instead
    static func getContactIds() -> [Int] {
        let cContacts = dc_get_contacts(mailboxPointer, 0, nil)
        return DcUtils.copyAndFreeArray(inputArray: cContacts)
    }

    static func getBlockedContactIds() -> [Int] {
        let cBlockedContacts = dc_get_blocked_contacts(mailboxPointer)
        return DcUtils.copyAndFreeArray(inputArray: cBlockedContacts)
    }

    static func getInitials(inputName: String) -> String {
        if let firstLetter = inputName.first {
            return firstLetter.uppercased()
        } else {
            return ""
        }
    }

    static func isValid(email: String) -> Bool {
        let emailRegEx = "(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
            + "~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
            + "x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
            + "z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
            + "]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
            + "9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
            + "-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])"

        let emailTest = NSPredicate(format: "SELF MATCHES[c] %@", emailRegEx)
        return emailTest.evaluate(with: email)
    }


    static func isEmail(url: URL) -> Bool {
        let mailScheme = "mailto"
        if let scheme = url.scheme {
            return mailScheme == scheme && isValid(email: url.absoluteString.substring(mailScheme.count + 1, url.absoluteString.count))
        }
        return false
    }

    static func getEmailFrom(_ url: URL) -> String {
        let mailScheme = "mailto"
        return url.absoluteString.substring(mailScheme.count + 1, url.absoluteString.count)
    }

    static func formatAddressForQuery(address: [String: String]) -> String {
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

    static func saveImage(image: UIImage) -> String? {
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false) as NSURL else {
            return nil
        }

        let size = image.size.applying(CGAffineTransform(scaleX: 0.2, y: 0.2))
        let hasAlpha = false
        let scale: CGFloat = 0.0

        UIGraphicsBeginImageContextWithOptions(size, !hasAlpha, scale)
        image.draw(in: CGRect(origin: CGPoint.zero, size: size))

        let scaledImageI = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let scaledImage = scaledImageI else {
            return nil
        }

        guard let data = scaledImage.jpegData(compressionQuality: 0.9) else {
            return nil
        }

        do {
            let timestamp = Int(Date().timeIntervalSince1970)
            let path = directory.appendingPathComponent("\(timestamp).jpg")
            try data.write(to: path!)
            return path?.relativePath
        } catch {
            logger.info(error.localizedDescription)
            return nil
        }
    }

    static func hasAudioSuffix(url: URL) -> Bool {
        ///TODO: add more file suffixes
        return url.absoluteString.hasSuffix("wav")
    }

    static func generateThumbnailFromVideo(url: URL) -> UIImage? {
        do {
            let asset = AVURLAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            // Select the right one based on which version you are using
            // Swift 4.2
            //let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            // Swift 4.0
            let cgImage = try imageGenerator.copyCGImage(at: CMTime.zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print(error.localizedDescription)

            return nil
        }
    }
}

class DateUtils {
    typealias DtU = DateUtils
    static let minute: Double = 60
    static let hour: Double = 3600
    static let day: Double = 86400
    static let year: Double = 365 * day

    private static func getRelativeTimeInSeconds(timeStamp: Double) -> Double {
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

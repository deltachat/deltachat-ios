import Foundation
import UIKit
import AVFoundation

struct Utils {
  static func getContactIds() -> [Int] {
    let cContacts = dc_get_contacts(mailboxPointer, 0, nil)
    return Utils.copyAndFreeArray(inputArray: cContacts)
  }

  static func getInitials(inputName: String) -> String {
    var nameParts = inputName.split(separator: " ")
		// this limits initials to max 2, otherwise just takes first letter to avoid messy badges
		if nameParts.count > 2 {
			nameParts = [nameParts[0]]
		}
    let initials: [Character] = nameParts.compactMap { part in part.capitalized.first }
    let initialsString: String = String(initials)
    return initialsString
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
    logger.info("got: \(from) \(len) \(lenArray) - \(acc)")

    return acc
  }

  static func isValid(_ email: String) -> Bool {
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
    guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL else {
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

	static func getBriefRelativeTimeSpanString(timeStamp: Int) -> String {
		let unixTime = Int(Date().timeIntervalSince1970)
		let seconds = unixTime - timeStamp

		if seconds < 60 {
			return "Now"	// under one minute
		} else if seconds < 3600 {
			let mins = seconds / 60
			let minTitle = mins > 1 ? "mins" : "min"
			return "\(mins) \(minTitle)"
		} else if seconds < 86400 {
			let hours = seconds / 3600
			let hoursTitle = hours > 1 ? "hours" : "hour"
			return "\(hours) \(hoursTitle)"
		} else {
			let date = Date(timeIntervalSince1970: Double(timeStamp))
			let dateFormatter = DateFormatter()
			// dateFormatter.timeStyle = DateFormatter.Style.short //Set time style
			dateFormatter.dateStyle = DateFormatter.Style.medium //Set date style
			dateFormatter.timeZone = .current
			let localDate = dateFormatter.string(from: date)
			return localDate
		}
	}
}


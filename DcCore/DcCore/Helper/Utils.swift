import Foundation
import UIKit
import AVFoundation

struct Utils {

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

}

import Foundation

public class DateUtils {
    typealias DtU = DateUtils
    static let minute: Double = 60
    static let hour: Double = 3600
    static let day: Double = 86400
    static let year: Double = 365 * day

    public static func getRelativeTimeInSeconds(timeStamp: Double) -> Double {
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

    /// Returns a string representation of the given date.
    /// - Parameters:
    ///   - date: The date to be formatted.
    ///   - relativeToCurrentDate: If true, the string will be relative to the current date. Eg. "Today", "Yesterday", "Tomorrow".
    public static func getDateString(date: Date, relativeToCurrentDate: Bool = false) -> String {
        let formatter = getLocalDateFormatter()
        formatter.dateStyle = .full
        formatter.doesRelativeDateFormatting = relativeToCurrentDate
        return formatter.string(from: date)
    }

    public static func getExtendedRelativeTimeSpanString(timeStamp: Double) -> String {
        let seconds = getRelativeTimeInSeconds(timeStamp: timeStamp)

        if seconds < DtU.minute {
            return String.localized("now")
        } else if seconds < DtU.hour {
            let mins = seconds / DtU.minute
            return String.localized(stringID: "n_minutes", parameter: Int(mins))
        } else {
            return getExtendedAbsTimeSpanString(timeStamp: timeStamp)
        }
    }

    public static func getExtendedAbsTimeSpanString(timeStamp: Double) -> String {
        let seconds = getRelativeTimeInSeconds(timeStamp: timeStamp)
        let date = Date(timeIntervalSince1970: timeStamp)
        let formatter = getLocalDateFormatter()
        let is24h = is24hDefault()

        if seconds < DtU.day {
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


    public static func getBriefRelativeTimeSpanString(timeStamp: Double) -> String {
        let seconds = getRelativeTimeInSeconds(timeStamp: timeStamp)
        let date = Date(timeIntervalSince1970: timeStamp)
        let formatter = getLocalDateFormatter()

        if seconds < DtU.minute {
            return String.localized("now")    // under one minute
        } else if seconds < DtU.hour {
            let mins = seconds / DtU.minute
            return String.localized(stringID: "n_minutes", parameter: Int(mins))
        } else if seconds < DtU.day {
            let hours = seconds / DtU.hour
            return String.localized(stringID: "n_hours", parameter: Int(hours))
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

    public static func getTimestamp() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "HH:mm:ss:SSS"
        return formatter.string(from: now)
    }
}

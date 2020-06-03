import Foundation


extension Date {

    var galleryLocalizedDescription: String {
        if isInToday {
            return String.localized("today")
        }
        if isInYesterday {
            return String.localized("yesterday")
        }
        if isInThisWeek {
            return String.localized("this_week")
        }
        if isInLastWeek {
            return String.localized("last_week")
        }
        if isInThisMonth {
            return String.localized("this_month")
        }
        if isInLastMonth {
            return String.localized("last_month")
        }

        let monthName = DateFormatter().monthSymbols[month - 1]
        let yearName: String = isInSameYear(as: Date()) ? "" : " \(year)"
        return "\(monthName)\(yearName)"
    }

}

private extension Date {

    func isEqual(
        to date: Date,
        toGranularity component: Calendar.Component,
        in calendar: Calendar = .current
    ) -> Bool {
        calendar.isDate(self, equalTo: date, toGranularity: component)
    }

    var isInToday: Bool { Calendar.current.isDateInToday(self) }
    var isInYesterday: Bool { Calendar.current.isDateInYesterday(self) }
    var isInThisWeek: Bool { isInSameWeek(as: Date()) }
    var isInLastWeek: Bool {
        guard let lastWeekDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) else {
            return false
        }
        return isEqual(to: lastWeekDate, toGranularity: .weekOfYear)
    }
    var isInThisMonth: Bool { isInSameMonth(as: Date()) }
    var isInLastMonth: Bool {
        guard let lastMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) else {
            return false
        }
        return isEqual(to: lastMonthDate, toGranularity: .month)
    }

    var month: Int {
       return Calendar.current.component(.month, from: self)
    }

    var year: Int {
        return Calendar.current.component(.year, from: self)
    }

    func isInSameMonth(as date: Date) -> Bool { isEqual(to: date, toGranularity: .month) }
    func isInSameWeek(as date: Date) -> Bool { isEqual(to: date, toGranularity: .weekOfYear) }
    func isInSameYear(as date: Date) -> Bool { isEqual(to: date, toGranularity: .year) }
}

import Foundation

extension Date {

    func isEqual(
        to date: Date,
        toGranularity component: Calendar.Component,
        in calendar: Calendar = .current
    ) -> Bool {
        calendar.isDate(self, equalTo: date, toGranularity: component)
    }

    func isInSameYear(as date: Date) -> Bool { isEqual(to: date, toGranularity: .year) }
    func isInSameMonth(as date: Date) -> Bool { isEqual(to: date, toGranularity: .month) }
    func isInSameWeek(as date: Date) -> Bool { isEqual(to: date, toGranularity: .weekOfYear) }

    func isInSameDay(as date: Date) -> Bool { Calendar.current.isDate(self, inSameDayAs: date) }

    var isInThisYear: Bool { isInSameYear(as: Date()) }
    var isInThisMonth: Bool { isInSameMonth(as: Date()) }
    var isInThisWeek: Bool { isInSameWeek(as: Date()) }
    var isInLastWeek: Bool {
        guard let lastWeekDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) else {
            return false
        }
        return isEqual(to: lastWeekDate, toGranularity: .weekOfYear)
    }

    var isInLastMonth: Bool {
        guard let lastMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) else {
            return false
        }
        return isEqual(to: lastMonthDate, toGranularity: .month)
    }


    var isInYesterday: Bool { Calendar.current.isDateInYesterday(self) }
    var isInToday: Bool { Calendar.current.isDateInToday(self) }
    var isInTomorrow: Bool { Calendar.current.isDateInTomorrow(self) }

    var isInTheFuture: Bool { self > Date() }
    var isInThePast: Bool { self < Date() }


}

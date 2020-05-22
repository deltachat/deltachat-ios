import Foundation

extension Date {

    func bucket() -> TimeBucket {
        if Calendar.current.isDateInToday(self) {
            return .today
        }
        if Calendar.current.isDateInYesterday(self) {
            return .yesterday
        }

        let today = Date()
        let earliest = self
        let latest = today

        let differenceComponents: DateComponents = Calendar.current.dateComponents (
            [.day, .weekOfYear, .month, .year],
            from: earliest,
            to: latest
        )

        let todayComponents: DateComponents = Calendar.current.dateComponents(
            [.day, .weekOfYear, .month, .year],
            from: today
        )

        let dateComponents: DateComponents = Calendar.current.dateComponents(
            [.day, .weekOfYear, .month, .year],
            from: self
        )

        let year = differenceComponents.year ?? 0
        let month = differenceComponents.month ?? 0
        let week = differenceComponents.weekOfYear ?? 0

        if year > 1 || month > 1 || month == 1 {
            return .lastMonth
        }

        if week > 1 {
            return .thisMonth
        }



        if month == 1 && dateComponents.month == todayComponents.month {
            return .thisMonth
        }

        if week > 1 {
            return .lastWeek
        }



    }
}

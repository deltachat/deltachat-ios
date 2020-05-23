import Foundation

enum TimeBucket: CaseIterable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case lastMonth
}

extension TimeBucket {

    static func bucket(for date: Date) -> TimeBucket {

        if date.isInToday {
            return .today
        }

        if date.isInYesterday {
            return .yesterday
        }
        if date.isInThisWeek {
            return .thisWeek
        }

        if date.isInLastWeek {
            return .lastWeek
        }

        if date.isInThisMonth {
            return .thisMonth
        }

        if date.isInLastMonth {
            return .lastMonth
        }

        // TODO: handle months
        return .lastMonth
    }

    var translationKey: String {
        switch self {
        case .today:
            return "today"
        case .yesterday:
            return "yesterday"
        case .thisWeek:
            return "this_week"
        case .lastWeek:
            return "last_week"
        case .thisMonth:
            return "this_month"
        case .lastMonth:
            return "last_month"
        }
    }
}

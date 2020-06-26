import UIKit

struct Constants {
    struct Color {
        static let bubble = UIColor(netHex: 0xEFFFDE)
    }

    struct Keys {
        static let deltachatUserProvidedCredentialsKey = "__DELTACHAT_USER_PROVIDED_CREDENTIALS_KEY__"
        static let deltachatImapEmailKey = "__DELTACHAT_IMAP_EMAIL_KEY__"
        static let deltachatImapPasswordKey = "__DELTACHAT_IMAP_PASSWORD_KEY__"
    }

    static let notificationIdentifier = "deltachat-ios-local-notifications"

    static var defaultCellHeight: CGFloat {
        return UIFont.preferredFont(forTextStyle: .body).pointSize + 32
    }
    static var defaultHeaderHeight: CGFloat {
        return UIFont.preferredFont(forTextStyle: .caption1).pointSize + 12
    }

}

struct Time {
    static let thirtySeconds = 30
    static let oneMinute = 60
    static let twoMinutes = 2 * 60
    static let fiveMinutes = 5 * 60
    static let thirtyMinutes = 30 * 6
    static let oneHour = 60 * 60
    static let twoHours = 2 * 60 * 60
    static let sixHours = 6 * 60 * 60
    static let oneDay = 24 * 60 * 60
    static let oneWeek = 7 * 24 * 60 * 60
    static let fourWeeks = 4 * 7 * 24 * 60 * 60
}

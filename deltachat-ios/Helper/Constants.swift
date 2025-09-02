import UIKit

struct Constants {
    struct Color {
        static let bubble = UIColor(netHex: 0xEFFFDE)
    }

    struct Keys {
        static let deltachatUserProvidedCredentialsKey = "__DELTACHAT_USER_PROVIDED_CREDENTIALS_KEY__"
        static let deltachatImapEmailKey = "__DELTACHAT_IMAP_EMAIL_KEY__"
        static let deltachatImapPasswordKey = "__DELTACHAT_IMAP_PASSWORD_KEY__"
        static let lastSelectedAccountKey = "__DELTACHAT_LAST_SELECTED_ACCOUNT_KEY__"
        static let backgroundImageName = "__BACKGROUND_IMAGE_NAME__"
        static let notificationTimestamps = "__NOTIFICATION_TIMESTAMPS__"
        static let lastDeviceMessageLabel = "last_device_message_label"
    }

    static let backgroundImageName = "BACKGROUND_IMAGE"
}

struct Time {
    static let fiveMinutes = 5 * 60
    static let thirtyMinutes = 30 * 60
    static let oneHour = 60 * 60
    static let twoHours = 2 * 60 * 60
    static let sixHours = 6 * 60 * 60
    static let eightHours = 8 * 60 * 60
    static let oneDay = 24 * 60 * 60
    static let oneWeek = 7 * 24 * 60 * 60
    static let fiveWeeks = 5 * 7 * 24 * 60 * 60
    static let oneYear = 365 * 24 * 60 * 60
}

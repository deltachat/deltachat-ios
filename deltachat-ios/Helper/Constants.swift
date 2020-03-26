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

    static let defaultShadow = UIImage(color: UIColor(hexString: "ff2b82"), size: CGSize(width: 1, height: 1))
    static let onlineShadow = UIImage(color: UIColor(hexString: "3ed67e"), size: CGSize(width: 1, height: 1))

    static let notificationIdentifier = "deltachat-ios-local-notifications"

    static let defaultCellHeight: CGFloat = 48
    static let defaultHeaderHeight: CGFloat = 20
}

struct Time {
    static let twoMinutes = 2 * 60
    static let fiveMinutes = 5 * 60
    static let thirtyMinutes = 30 * 6
    static let oneHour = 60 * 60
    static let twoHours = 2 * 60 * 60
    static let sixHours = 6 * 60 * 60
}

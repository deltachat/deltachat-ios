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

    static let stdCellHeight: CGFloat = 48
}

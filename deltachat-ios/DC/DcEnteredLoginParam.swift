import Foundation

public struct DcEnteredLoginParam: Codable {
    public var addr: String
    public var certificateChecks: String?
    public var imapPort: Int?
    public var imapSecurity: String?
    public var imapServer: String?
    public var imapUser: String?
    public var oauth2: Bool?
    public var password: String?
    public var smtpPassword: String?
    public var smtpPort: Int?
    public var smtpSecurity: String?
    public var smtpServer: String?
    public var smtpUser: String?

    public init(addr: String) {
        self.addr = addr
    }

    public static func socketSecurity(fromInt: Int) -> String {
        switch fromInt {
        case 1: return "ssl"
        case 2: return "starttls"
        case 3: return "plain"
        default: return "automatic"
        }
    }

    public static func certificateChecks(fromInt: Int) -> String {
        switch fromInt {
        case 1: return "strict"
        case 2: return "acceptInvalidCertificates"
        default: return "automatic"
        }
    }
}

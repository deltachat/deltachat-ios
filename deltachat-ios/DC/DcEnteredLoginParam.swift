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
        switch Int32(fromInt) {
        case DC_SOCKET_SSL: return "ssl"
        case DC_SOCKET_STARTTLS: return "starttls"
        case DC_SOCKET_PLAIN: return "plain"
        default: return "automatic"
        }
    }

    public static func certificateChecks(fromInt: Int) -> String {
        switch Int32(fromInt) {
        case DC_CERTCK_STRICT: return "strict"
        case DC_CERTCK_ACCEPT_INVALID: return "acceptInvalidCertificates"
        default: return "automatic"
        }
    }
}

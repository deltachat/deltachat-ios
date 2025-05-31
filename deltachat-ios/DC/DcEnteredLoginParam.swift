import Foundation

public struct DcEnteredLoginParam: Codable {
    public let addr: String
    public let certificateChecks: String?
    public let imapPort: Int?
    public let imapSecurity: String?
    public let imapServer: String?
    public let imapUser: String?
    public let oauth2: Bool?
    public let password: String?
    public let smtpPassword: String?
    public let smtpPort: Int?
    public let smtpSecurity: String?
    public let smtpServer: String?
    public let smtpUser: String?

    public init(addr: String) {
        self.addr = addr
        self.certificateChecks = nil
        self.imapPort = nil
        self.imapSecurity = nil
        self.imapServer = nil
        self.imapUser = nil
        self.oauth2 = nil
        self.password = nil
        self.smtpPassword = nil
        self.smtpPort = nil
        self.smtpSecurity = nil
        self.smtpServer = nil
        self.smtpUser = nil
    }
}

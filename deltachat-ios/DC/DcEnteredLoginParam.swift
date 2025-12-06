import Foundation

public struct DcEnteredLoginParam: Codable {
    public var addr: String
    public var certificateChecks: String?
    public var imapPort: Int?
    public var imapSecurity: String?
    public var imapServer: String?
    public var imapUser: String?
    public var oauth2: Bool?
    public var password: String
    public var smtpPassword: String?
    public var smtpPort: Int?
    public var smtpSecurity: String?
    public var smtpServer: String?
    public var smtpUser: String?

    public init(addr: String, password: String) {
        self.addr = addr
        self.password = password
    }
}

struct DcEnteredLoginParamResult: Decodable {
    let result: [DcEnteredLoginParam]
}

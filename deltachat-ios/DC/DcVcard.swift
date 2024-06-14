import Foundation

public struct DcVcardContact: Decodable {
    /// Email address.
    public let addr: String

    /// The contact's name, or the email address if no name was given.
    public let displayName: String

    /// Public PGP key in Base64.
    public let key: String?

    /// Profile image in Base64.
    public let profileImage: String?

    /// Contact color as hex string.
    public let color: String

    // Last update timestamp.
    public let timestamp: Int64?
}

struct DcVcardContactResult: Decodable {
    let result: [DcVcardContact]
}

struct DcVcardImportResult: Decodable {
    let result: [Int]
}

struct DcVCardMakeResult: Decodable {
    let result: String
}

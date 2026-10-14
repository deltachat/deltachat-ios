public struct WebxdcInfo: Decodable {
    public let name: String
    public let icon: String
    public let document: String?
    public let summary: String?
    /// Note that core sends an empty string as default which is not a valid URL so we can't use URL decoding
    public let sourceCodeUrl: String?
    public let internetAccess: Bool
    public let selfAddr: String
    public let isAppSender: Bool
    public let isBroadcast: Bool
    public let sendUpdateInterval: Int
    public let sendUpdateMaxSize: Int
}

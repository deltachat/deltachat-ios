import Foundation

public struct DcTransportListEntry: Decodable {
    public let isUnpublished: Bool
    public let param: DcEnteredLoginParam
}

struct DcTransportListEntryResult: Decodable {
    let result: [DcTransportListEntry]
}

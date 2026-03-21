import Foundation

public struct DcTransportListEntry: Decodable {
    public let isUnpublished: Bool
    public let param: DcEnteredLoginParam
}

typealias DcTransportListEntryResult = JsonrpcResult<[DcTransportListEntry]>

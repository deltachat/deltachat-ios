import Foundation

public struct DcReaction: Decodable {
    public let count: Int
    public let emoji: String
    public let isFromSelf: Bool

    public init(count: Int = 1, emoji: String, isFromSelf: Bool = false) {
        self.emoji = emoji
        self.count = count
        self.isFromSelf = isFromSelf
    }
}

public struct DcReactions: Decodable {
    public let reactions: [DcReaction]
    public let reactionsByContact: [Int: [String]]
}

struct DcReactionResult: Decodable {
    let result: DcReactions?
}

import UIKit
import DcCore

enum DefaultReactions: CaseIterable {
    case thumbsUp
    case thumbsDown
    case heart
    case haha
    case sad

    var emoji: String {
        switch self {
        case .thumbsUp: return "👍"
        case .thumbsDown: return "👎"
        case .heart: return "❤️"
        case .haha: return "😂"
        case .sad: return "🙁"
        }
    }
}

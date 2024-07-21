import UIKit
import DcCore

enum DefaultReactions: CaseIterable {
    case thumbsUp
    case thumbsDown
    case heart
    case faceWithTearsOfJoy
    case sad

    var emoji: String {
        switch self {
        case .thumbsUp: return "👍"
        case .thumbsDown: return "👎"
        case .heart: return "❤️"
        case .faceWithTearsOfJoy: return "😂"
        case .sad: return "🙁"
        }
    }
}

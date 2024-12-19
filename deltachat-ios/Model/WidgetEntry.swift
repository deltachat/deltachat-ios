import Foundation

struct WidgetEntry: Codable, Equatable {
    let accountId: Int
    let type: Type

    enum `Type`: Codable, Hashable {
        case chat(chatId: Int)
        case app(messageId: Int)
    }
}

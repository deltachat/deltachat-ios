import Foundation

struct WidgetEntry: Codable, Equatable {
    let accountId: Int
    let type: WidgetEntryType

    enum WidgetEntryType: Codable, Hashable {
        case chat(chatId: Int)
        case app(messageId: Int)
    }
}

import DcCore
import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsedWebxdcEntry {
        let limit: Int
        switch context.family {
        case .systemSmall:
            limit = 4
        case .systemMedium:
            limit = 7
        default:
            limit = 7
        }

        let shortcuts: [Shortcut] = [
            .app(AppShortcut(accountId: 0, chatId: 0, messageId: 0, image: UIImage(named: "checklist"), title: "checklist")),
            .app(AppShortcut(accountId: 0, chatId: 1, messageId: 1, image: UIImage(named: "hello"), title: "hello")),
            .app(AppShortcut(accountId: 0, chatId: 2, messageId: 2, image: UIImage(named: "packabunchas"), title: "packabunchas")),
            .chat(ChatShortcut(accountId: 0, chatId: 3, title: "Messages to self", image: UIImage(named: "saved-messages"), color: .green)),
            .app(AppShortcut(accountId: 0, chatId: 4, messageId: 4, image: UIImage(named: "pixel"), title: "pixel")),
            .app(AppShortcut(accountId: 0, chatId: 5, messageId: 5, image: UIImage(named: "webxdc"), title: "webxdc")),
            .chat(ChatShortcut(accountId: 0, chatId: 6, title: "Broadcast", image: UIImage(named: "broadcast"), color: .red)),
        ]

        return UsedWebxdcEntry(date: Date(), shortcuts: Array(shortcuts.prefix(limit)))
    }

    func getSnapshot(in context: Context, completion: @escaping (UsedWebxdcEntry) -> Void) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsedWebxdcEntry>) -> Void) {
        /// ----------------------------------
        /// **DO NOT** start dcAccounts.startIo() in widget.
        /// This works only for one process, and widgets may run concurrently to the main app in their own process.
        /// ----------------------------------
        let dcAccounts = DcAccounts.shared
        dcAccounts.openDatabase(writeable: false)

        let limit: Int
        switch context.family {
        case .systemSmall: limit = 4
        case .systemMedium: limit = 8
        default: limit = 8
        }

        let entries = UserDefaults.shared?.getAllWidgetEntries() ?? []
        let shortcuts: [Shortcut] = entries
            .prefix(limit)
            .compactMap { entry in
                let dcContext = dcAccounts.get(id: entry.accountId)
                let accountId = entry.accountId

                switch entry.type {
                case .app(let messageId):
                    let msg = dcContext.getMessage(id: messageId)
                    guard msg.isValid else { return nil }
                    
                    let name = msg.getWebxdcAppName()
                    let image = msg.getWebxdcPreviewImage()

                    let chatId = msg.chatId

                    return .app(AppShortcut(
                        accountId: accountId,
                        chatId: chatId,
                        messageId: msg.id,
                        image: image,
                        title: name
                    ))

                case .chat(let chatId):
                    let chat = dcContext.getChat(chatId: chatId)
                    guard chat.isValid else { return nil }
                    
                    let title = chat.name
                    let image = chat.profileImage
                    let color = chat.color

                    return .chat(ChatShortcut(
                        accountId: entry.accountId,
                        chatId: chatId,
                        title: title,
                        image: image,
                        color: color
                    ))
                }
            }
        dcAccounts.closeDatabase()

        let currentDate = Date()
        let entry = UsedWebxdcEntry(date: currentDate, shortcuts: shortcuts)

        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct UsedWebxdcEntry: TimelineEntry {
    let date: Date
    let shortcuts: [Shortcut]
}

enum Shortcut: Identifiable {
    var id: String {
        switch self {
        case .app(let webxdcApp):
            return webxdcApp.id
        case .chat(let widgetChat):
            return widgetChat.id
        }
    }

    case app(AppShortcut)
    case chat(ChatShortcut)
}

struct ChatShortcut: Identifiable, Hashable {
    var id: String { "chat-\(accountId)-\(chatId)" }

    let accountId: Int
    let chatId: Int
    let title: String
    let image: UIImage?
    let color: UIColor

    var url: URL {
        var urlComponents = URLComponents()
        urlComponents.scheme = "chat.delta.deeplink"
        urlComponents.host = "chat"
        urlComponents.queryItems = [
            URLQueryItem(name: "chatId", value: "\(chatId)"),
            URLQueryItem(name: "accountId", value: "\(accountId)"),
        ]

        return urlComponents.url!
    }
}

struct AppShortcut: Identifiable, Hashable {
    var id: String { "app-\(accountId)-\(messageId)" }

    let accountId: Int
    let chatId: Int
    let messageId: Int

    let image: UIImage?
    let title: String

    var url: URL {
        var urlComponents = URLComponents()
        urlComponents.scheme = "chat.delta.deeplink"
        urlComponents.host = "webxdc"
        urlComponents.queryItems = [
            URLQueryItem(name: "msgId", value: "\(messageId)"),
            URLQueryItem(name: "chatId", value: "\(chatId)"),
            URLQueryItem(name: "accountId", value: "\(accountId)"),
        ]

        return urlComponents.url!
    }
}

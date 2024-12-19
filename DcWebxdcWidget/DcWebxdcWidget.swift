import WidgetKit
import SwiftUI
import DcCore

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

        let apps = [
            WebxdcApp(accountId: 0, chatId: 0, messageId: 0, image: UIImage(named: "checklist"), title: "checklist"),
            WebxdcApp(accountId: 0, chatId: 0, messageId: 1, image: UIImage(named: "hello"), title: "hello"),
            WebxdcApp(accountId: 0, chatId: 0, messageId: 6, image: UIImage(named: "packabunchas"), title: "packabunchas"),
            WebxdcApp(accountId: 0, chatId: 0, messageId: 3, image: UIImage(named: "webxdc"), title: "webxdc"),
            WebxdcApp(accountId: 0, chatId: 0, messageId: 2, image: UIImage(named: "pixel"), title: "pixel"),
            WebxdcApp(accountId: 0, chatId: 0, messageId: 4, image: UIImage(named: "checklist"), title: "checklist"),
            WebxdcApp(accountId: 0, chatId: 0, messageId: 5, image: UIImage(named: "hello"), title: "hello"),
            WebxdcApp(accountId: 0, chatId: 0, messageId: 7, image: UIImage(named: "webxdc"), title: "webxdc"),
        ]

        return UsedWebxdcEntry(date: Date(), apps: Array(apps.prefix(limit)))
    }

    func getSnapshot(in context: Context, completion: @escaping (UsedWebxdcEntry) -> Void) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
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
        let apps = entries
            .prefix(limit)
            .compactMap { entry in
                let dcContext = dcAccounts.get(id: entry.accountId)
                let msg = dcContext.getMessage(id: entry.messageId)
                let name = msg.getWebxdcAppName()
                let image = msg.getWebxdcPreviewImage()
                let accountId = entry.accountId
                let chatId = msg.chatId
                
                return WebxdcApp(
                    accountId: accountId,
                    chatId: chatId,
                    messageId: msg.id,
                    image: image,
                    title: name
                )
            }
        
        let currentDate = Date()
        let entry = UsedWebxdcEntry(date: currentDate, apps: apps)
        let nextDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!

        let timeline = Timeline(entries: [entry], policy: .after(nextDate))
        completion(timeline)
    }
}

struct UsedWebxdcEntry: TimelineEntry {

    let date: Date
    let apps: [WebxdcApp]
}

struct WebxdcApp: Hashable, Identifiable {
    var id: Int { messageId }

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

struct DcWebxdcWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        if entry.apps.isEmpty {
            Text(String.localized("ios_widget_no_apps"))
        } else {
            let rows = [GridItem(.fixed(56)), GridItem(.fixed(56))]
            LazyHGrid(rows: rows) {
                ForEach(entry.apps) { app in
                    WebXDCAppView(app: app).accessibilityLabel(Text(app.title))
                }
            }
        }
    }
}

struct WebXDCAppView: View {
    var app: WebxdcApp

    var body: some View {
        Link(destination: app.url) {
            if let image = app.image {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .cornerRadius(12)
            } else {
                Color(.systemBackground)
                    .frame(width: 56, height: 56)
                    .cornerRadius(12)
            }
        }
    }
}

struct DcWebxdcWidget: Widget {
    let kind: String = "DcWebxdcWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                DcWebxdcWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                DcWebxdcWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .supportedFamilies([.systemSmall, .systemMedium]) 
        .configurationDisplayName(String.localized("ios_widget_apps_title"))
        .description(String.localized("ios_widget_apps_description"))
    }
}

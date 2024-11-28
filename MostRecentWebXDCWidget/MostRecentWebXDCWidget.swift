import WidgetKit
import SwiftUI
import DcCore

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsedWebXDCEntry {
        UsedWebXDCEntry(date: Date(), apps: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (UsedWebXDCEntry) -> Void) {
        let entry = UsedWebXDCEntry(date: Date(), apps: [])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let dcAccounts = DcAccounts.shared
        dcAccounts.openDatabase(writeable: false)
        for accountId in dcAccounts.getAll() {
            let dcContext = dcAccounts.get(id: accountId)
            if dcContext.isOpen() == false {
                do {
                    let secret = try KeychainManager.getAccountSecret(accountID: accountId)
                    _ = dcContext.open(passphrase: secret)
                } catch {
                    debugPrint("Couldn't open \(error.localizedDescription)")
                }
            }
        }

        let dcContext = dcAccounts.getSelected()
        let chatId = 0
        let ignore = Int32(0)

        let limit: Int
        switch context.family {
        case .systemSmall: limit = 2
        case .systemMedium: limit = 4
        default: limit = 8
        }

        let messageIds: [Int] = Array(dcContext.getChatMedia(chatId: chatId, messageType: DC_MSG_WEBXDC, messageType2: ignore, messageType3: ignore).reversed().prefix(limit))

        let apps = messageIds.compactMap {
            dcContext.getMessage(id: $0)
        }.compactMap { msg in
            let name = msg.getWebxdcAppName()
            let image = msg.getWebxdcPreviewImage()
            let accountId = dcContext.id
            let chatId = msg.chatId

            return WebXDCApp(
                accountId: accountId,
                chatId: chatId,
                messageId: msg.id,
                image: image,
                title: name
            )
        }

        let currentDate = Date()
        let entry = UsedWebXDCEntry(date: currentDate, apps: apps)
        let nextDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!

        let timeline = Timeline(entries: [entry], policy: .after(nextDate))
        completion(timeline)
    }
}

struct UsedWebXDCEntry: TimelineEntry {

    let date: Date
    let apps: [WebXDCApp]
}

struct WebXDCApp: Hashable, Identifiable {
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

struct MostRecentWebXDCWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        if entry.apps.isEmpty {
            Text("No apps (yet)")
        } else {
            // TODO: Use Grid!
            VStack(alignment: .leading) {
                ForEach(entry.apps) { app in
                    WebXDCAppView(app: app)
                }
            }
        }
    }
}

struct WebXDCAppView: View {
    var app: WebXDCApp

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

// TODO: Localization
struct MostRecentWebXDCWidget: Widget {
    let kind: String = "MostRecentWebXDCWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                MostRecentWebXDCWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                MostRecentWebXDCWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .supportedFamilies([.systemSmall, .systemMedium]) 
        .configurationDisplayName("Most Recent WebXDC-apps")
        .description("Shows the n moth recent WebXDC-apps")
    }
}

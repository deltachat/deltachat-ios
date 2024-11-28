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
        var entries: [UsedWebXDCEntry] = []
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
        let messageIds: [Int] = Array(dcContext.getChatMedia(chatId: chatId, messageType: DC_MSG_WEBXDC, messageType2: ignore, messageType3: ignore).reversed().prefix(upTo: 3))

        let apps = messageIds.compactMap {
            dcContext.getMessage(id: $0)
        }.compactMap { msg in
            let name = msg.getWebxdcAppName()
            let image = msg.getWebxdcPreviewImage()

            return UsedWebXDCEntry.WebXDCApp(id: msg.id, image: image, title: name)
        }

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            // Get the four most recent entries
            let entry = UsedWebXDCEntry(date: entryDate, apps: apps)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct UsedWebXDCEntry: TimelineEntry {

    let date: Date
    fileprivate let apps: [WebXDCApp]

    fileprivate struct WebXDCApp: Hashable, Identifiable {
        var id: Int

        let image: UIImage?
        let title: String
    }
}

struct MostRecentWebXDCWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        if entry.apps.isEmpty {
            Text("No apps (yet)")
        } else {
            VStack(alignment: .leading) {
                ForEach(entry.apps) { app in

                    Button {
                        print("open...")
                        // TODO: Open deeplink with chatId and messageId etc.
                    } label: {
                        HStack {
                            if let image = app.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .cornerRadius(4)
                            }
                            Text(app.title)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

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
        .configurationDisplayName("Most Recent WebXDC-apps")
        .description("Shows the n moth recent WebXDC-apps")
    }
}

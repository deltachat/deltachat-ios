import WidgetKit
import SwiftUI
import DcCore

struct DcWebxdcWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        if entry.shortcuts.isEmpty {
            Text(String.localized("ios_widget_no_apps"))
        } else {
            let rows = [GridItem(.fixed(56)), GridItem(.fixed(56))]
            LazyHGrid(rows: rows) {
                ForEach(entry.shortcuts) { shortcut in
                    switch shortcut {
                    case .app(let app):
                        AppShortcutView(app: app)
                    case .chat(let chat):
                        ChatShortcutView(chat: chat)
                    }
                }
            }
        }
    }
}

struct AppShortcutView: View {
    var app: AppShortcut

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

struct ChatShortcutView: View {
    var chat: ChatShortcut

    var body: some View {
        Link(destination: chat.url) {
            if let image = chat.image {
                // Use Circle as mask
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
            } else {
                Color(.systemBackground)
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
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

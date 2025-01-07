import WidgetKit
import SwiftUI
import DcCore

struct DcShortcutWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        if entry.shortcuts.isEmpty {
            Text(String.localized("shortcuts_widget_description"))
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
                    .fullColor()
            } else {
                Color(.systemBackground)
            }
        }
        .frame(width: 56, height: 56)
        .cornerRadius(12)
    }
}

struct ChatShortcutView: View {
    var chat: ChatShortcut

    var body: some View {
        Link(destination: chat.url) {
            if let image = chat.image {
                Image(uiImage: image)
                    .fullColor()
            } else if let colorImage = UIImage(color: chat.color, size: CGSize(width: 56, height: 56)) {
                ZStack {
                    Image(uiImage: colorImage)
                    Text(DcUtils.getInitials(inputName: chat.title))
                        .foregroundStyle(.white)
                        .font(.system(size: 34))
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }
}

struct DcWidget: Widget {
    let kind: String = "DcWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                DcShortcutWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                DcShortcutWidgetView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName(String.localized("shortcuts_widget_title"))
        .description(String.localized("shortcuts_widget_description"))
    }
}

extension Image {
    @ViewBuilder func fullColor() -> some View {
        if #available(iOS 18, *) {
            self.resizable()
                .widgetAccentedRenderingMode(.fullColor)
        } else {
            self.resizable()
        }
    }
}

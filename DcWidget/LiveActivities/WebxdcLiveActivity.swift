import DcCore
import WidgetKit
import SwiftUI

struct WebxdcLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WebxdcLiveActivityAttributes.self) { context in
            HStack {
                let info = context.state.info
                let attr = context.attributes
                if let image = LiveActivityIconStore.loadThumbnail(contextId: attr.contextId, messageId: attr.messageId) {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .cornerRadius(5)
                }
                VStack(alignment: .leading) {
                    Text("\(info.document?.nilIfEmpty ?? info.name) – \(attr.chatName)").bold()
                    if let summary = info.summary?.nilIfEmpty {
                        Text(summary)
                    }
                }
                .lineLimit(1)
                .layoutPriority(-1)
                Spacer()
                VStack {
                    switch context.state.connectivity {
                    case DC_CONNECTIVITY_CONNECTED, DC_CONNECTIVITY_WORKING:
                        Text(String.localized("connectivity_connected"))
                    case DC_CONNECTIVITY_CONNECTING:
                        Text(String.localized("connectivity_connecting"))
                    default:
                        Text(String.localized("connectivity_not_connected"))
                    }
                }.font(.footnote)
                Button(intent: QuitWebxdcIntent(contextId: attr.contextId, messageId: attr.messageId)) {
                    Label(String.localized("close"), systemImage: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .opacity(0.8)
                        .labelStyle(.iconOnly)
                }.buttonStyle(.plain)
            }
            .padding()
            .widgetURL(context.attributes.url)
        } dynamicIsland: { context in
            let info = context.state.info
            let attr = context.attributes
            let image = LiveActivityIconStore.loadThumbnail(
                contextId: context.attributes.contextId,
                messageId: context.attributes.messageId
            ).map {
                Image(uiImage: $0)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
            }

            return DynamicIsland(expanded: {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        switch context.state.connectivity {
                        case DC_CONNECTIVITY_CONNECTED, DC_CONNECTIVITY_WORKING:
                            Text(String.localized("connectivity_connected"))
                        case DC_CONNECTIVITY_CONNECTING:
                            Text(String.localized("connectivity_connecting"))
                        default:
                            Text(String.localized("connectivity_not_connected"))
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(color(for: context.state.connectivity))
                    .padding(.leading, 10)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: QuitWebxdcIntent(contextId: attr.contextId, messageId: attr.messageId)) {
                        Label(String.localized("close"), systemImage: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .opacity(0.8)
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 10)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        image
                            .frame(width: 50, height: 50)
                            .cornerRadius(6)
                            .padding(.leading, 6)
                            .padding(.bottom, 6)
                        VStack(alignment: .leading) {
                            Text("\(info.document?.nilIfEmpty ?? info.name) – \(attr.chatName)").bold()
                            if let summary = info.summary?.nilIfEmpty {
                                Text(summary).padding(.trailing)
                            }
                        }.lineLimit(1)
                        Spacer()
                    }
                }
            }, compactLeading: {
                Image(systemName: "circle")
                    .opacity(0)
                    .overlay(image.cornerRadius(2))
            }, compactTrailing: {

            }, minimal: {
                Image(systemName: "circle")
                    .opacity(0)
                    .overlay(image.cornerRadius(2))
            })
            .widgetURL(context.attributes.url)
        }
    }

    func color(for connectivity: Int32) -> Color {
        switch connectivity {
        case DC_CONNECTIVITY_CONNECTED, DC_CONNECTIVITY_WORKING:
            Color.green
        case DC_CONNECTIVITY_CONNECTING:
            Color.orange
        default:
            Color.red
        }
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

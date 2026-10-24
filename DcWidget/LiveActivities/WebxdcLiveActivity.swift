import DcCore
import WidgetKit
import SwiftUI

struct WebxdcLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WebxdcLiveActivityAttributes.self) { context in
            HStack {
                let info = context.state.info
                if let image = LiveActivityIconStore.loadThumbnail(contextId: context.attributes.contextId, messageId: context.attributes.messageId) {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .cornerRadius(5)
                }
                VStack(alignment: .leading) {
                    Text("\(info.document?.nilIfEmpty ?? info.name) – \(context.attributes.chatName)")
                        .bold()
                        .lineLimit(1)
                    if let summary = info.summary?.nilIfEmpty {
                        Text(summary)
                    }
                }
                Spacer()
                // TODO: Button to close webxdc
                VStack(alignment: .trailing) {
                    switch context.state.connectivity {
                    case DC_CONNECTIVITY_CONNECTED, DC_CONNECTIVITY_WORKING:
                        Text(String.localized("connectivity_connected"))
                    case DC_CONNECTIVITY_CONNECTING:
                        Text(String.localized("connectivity_connecting"))
                    default:
                        Text(String.localized("connectivity_not_connected"))
                    }
                }.font(.footnote)
            }
            .padding()
            .widgetURL(context.attributes.url)
        } dynamicIsland: { context in

            let image = LiveActivityIconStore.loadThumbnail(
                contextId: context.attributes.contextId,
                messageId: context.attributes.messageId
            ).map {
                Image(uiImage: $0)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
            }

            return DynamicIsland(expanded: {
                DynamicIslandExpandedRegion(.leading, priority: -1) {
                    image.dynamicIsland(verticalPlacement: .belowIfTooWide)
                    Image(systemName: "circle")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Hi")
                }
            }, compactLeading: {
                Image(systemName: "circle")
                    .opacity(0)
                    .overlay(image.cornerRadius(2))
            }, compactTrailing: {

            }, minimal: {
                image
            })
            .widgetURL(context.attributes.url)
        }
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

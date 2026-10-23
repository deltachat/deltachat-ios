import DcCore
import WidgetKit
import SwiftUI

struct WebxdcLiveActivity: Widget {
    var body: some WidgetConfiguration {

        ActivityConfiguration(for: WebxdcLiveActivityAttributes.self) { context in
            let dcContext = DcAccounts.shared.get(id: context.attributes.contextId)
            let dcMsg = dcContext.getMessage(id: context.attributes.messageId)
            let image = dcMsg.getWebxdcPreviewImage()

            Image(uiImage: image ?? UIImage(named: "dc_logo")!)
            // Create the presentation that appears on the Lock Screen and as a
            // banner on the Home Screen of devices that don't support the
            // Dynamic Island.
        } dynamicIsland: { context in
            let dcContext = DcAccounts.shared.get(id: context.attributes.contextId)
            let dcMsg = dcContext.getMessage(id: context.attributes.messageId)
            let uiImage = dcMsg.getWebxdcPreviewImage()

            let image: () -> some View = {
                Image(uiImage: uiImage ?? UIImage(named: "dc_logo")!)
            }

            return DynamicIsland(expanded: {
                DynamicIslandExpandedRegion(.leading, priority: -1) {
                    image().dynamicIsland(verticalPlacement: .belowIfTooWide)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Hi")
                }
            }, compactLeading: image, compactTrailing: image, minimal: image)

        }
    }
}

import WidgetKit
import SwiftUI

@main
struct DcWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 17, *) { // Requires Link to open the app which is iOS 17+
            DcWidget()
        }
        if #available(iOS 16.1, *) {
            WebxdcLiveActivity()
        }
    }
}

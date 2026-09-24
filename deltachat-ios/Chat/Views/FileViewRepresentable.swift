import DcCore
import SwiftUI

struct FileViewRepresentable: UIViewRepresentable {
    var message: DcMsg
    var webxdcSummary: String

    func makeUIView(context: Context) -> FileView {
        let uiView = FileView()
        uiView.horizontalLayout = true
        uiView.allowLayoutChange = false
        return uiView
    }

    func updateUIView(_ uiView: FileView, context: Context) {
        uiView.configure(message: message, forceWebxdcSummary: webxdcSummary)
        uiView.fileTitle.numberOfLines = 1
    }
}

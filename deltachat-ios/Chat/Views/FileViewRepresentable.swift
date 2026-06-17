import DcCore
import SwiftUI

private struct FileViewRepresentable: UIViewRepresentable {
    var message: DcMsg
    var webxdcSummary: String

    func makeUIView(context: Context) -> FileView {
        FileView()
    }

    func updateUIView(_ uiView: FileView, context: Context) {
        uiView.configure(message: message, forceWebxdcSummary: webxdcSummary)
    }
}

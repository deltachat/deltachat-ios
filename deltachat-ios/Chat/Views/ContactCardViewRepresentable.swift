import DcCore
import SwiftUI

private struct ContactCardViewRepresentable: UIViewRepresentable {
    var message: DcMsg
    var dcContext: DcContext

    func makeUIView(context: Context) -> ContactCardView {
        ContactCardView()
    }

    func updateUIView(_ uiView: ContactCardView, context: Context) {
        uiView.configure(message: message, dcContext: dcContext)
    }
}

import DcCore
import SwiftUI

struct ContactCardViewRepresentable: UIViewRepresentable {
    var message: DcMsg
    var dcContext: DcContext

    func makeUIView(context: Context) -> ContactCardView {
        ContactCardView()
    }

    func updateUIView(_ uiView: ContactCardView, context: Context) {
        uiView.configure(message: message, dcContext: dcContext)
    }
}

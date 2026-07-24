import SwiftUI
import Translation
import UIKit

extension ChatViewController {
    @available(iOS 17.4, *)
    func presentTranslation(text: String) {
        let host = UIHostingController(rootView: TranslationPresentationView(text: text, onDismiss: { [weak self] in
            self?.translationPresentationHost?.willMove(toParent: nil)
            self?.translationPresentationHost?.view.removeFromSuperview()
            self?.translationPresentationHost?.removeFromParent()
            self?.translationPresentationHost = nil
        }))
        translationPresentationHost = host
        addChild(host)
        view.addSubview(host.view)
        host.view.fillSuperview()
        host.view.backgroundColor = .clear
        host.didMove(toParent: self)
    }
}

@available(iOS 17.4, *)
private struct TranslationPresentationView: View {
    let text: String
    let onDismiss: () -> Void
    @State private var isPresented = true

    var body: some View {
        Color.clear
            .translationPresentation(isPresented: $isPresented, text: text)
            .onChange(of: isPresented) { if !$0 { onDismiss() } }
    }
}

import SwiftUI
import Combine

struct InputBarTextView: View {
    @Binding var text: String
    @State private var contentSize: CGSize = .zero
    weak var imagePasteDelegate: ChatInputTextViewPasteDelegate?

    var body: some View {
        _InputBarTextView(
            text: $text,
            contentSize: $contentSize,
            imagePasteDelegate: imagePasteDelegate
        ).frame(idealHeight: contentSize.height, alignment: .center)
    }
}

private struct _InputBarTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var contentSize: CGSize
    weak var imagePasteDelegate: ChatInputTextViewPasteDelegate?

    func makeUIView(context: Context) -> ChatInputTextView {
        let textView = ChatInputTextView()
        textView.keyboardDismissMode = .none
        textView.delegate = context.coordinator
        textView.adjustsFontForContentSizeCategory = true
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.autocapitalizationType = .sentences
        context.coordinator.contentSizePublisher = textView.publisher(for: \.contentSize)
            .receive(on: RunLoop.main)
            .assign(to: \.contentSize, on: self)
        return textView
    }

    func updateUIView(_ uiView: ChatInputTextView, context: Context) {
        uiView.text = text
        uiView.imagePasteDelegate = imagePasteDelegate
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var contentSizePublisher: AnyCancellable?

        init(text: Binding<String>) {
            self._text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            self.text = textView.text
        }
    }
}

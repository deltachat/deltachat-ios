import SwiftUI

extension View {
    func onWillDisappear(_ perform: @escaping () -> Void) -> some View {
        self.background(MissingAppearHandlers(onWillDisappear: perform))
    }

    func onDidAppear(_ perform: @escaping () -> Void) -> some View {
        self.background(MissingAppearHandlers(onDidAppear: perform))
    }
}

private struct MissingAppearHandlers: UIViewControllerRepresentable {
    var onWillDisappear: () -> Void = {}
    var onDidAppear: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onWillDisappear: onWillDisappear, onDidAppear: onDidAppear)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        context.coordinator
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    class Coordinator: UIViewController {
        let onWillDisappear: () -> Void
        let onDidAppear: () -> Void

        init(onWillDisappear: @escaping () -> Void, onDidAppear: @escaping () -> Void) {
            self.onWillDisappear = onWillDisappear
            self.onDidAppear = onDidAppear
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            onWillDisappear()
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onDidAppear()
        }
    }
}

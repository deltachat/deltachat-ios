import QuickLook
import UIKit

class PreviewController: QLPreviewControllerDataSource {

    var onDismiss: VoidFunction?

    var urls: [URL]
    var qlController: QLPreviewController

    init(currentIndex: Int, urls: [URL]) {
        self.urls = urls
        qlController = QLPreviewController()
        qlController.dataSource = self
        qlController.currentPreviewItemIndex = currentIndex
    }

    func numberOfPreviewItems(in _: QLPreviewController) -> Int {
        return urls.count
    }

    func previewController(_: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return urls[index] as QLPreviewItem
    }
}


class BetterPreviewController: QLPreviewController {
    var onDismiss: VoidFunction?
    var urls: [URL]

    private lazy var doneButtonItem: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "Fertig", style: .done, target: self, action: #selector(doneButtonPressed(_:)))
        return button
    }()

    init(currentIndex: Int, urls: [URL]) {
        self.urls = urls
        super.init(nibName: nil, bundle: nil)
        dataSource = self
        delegate = self
        currentPreviewItemIndex = currentIndex
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = doneButtonItem
        navigationController?.presentationController?.delegate = self
    }

    // MARK: - actions
    @objc private func doneButtonPressed(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension BetterPreviewController: QLPreviewControllerDelegate {
    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        print("Preview dismissed")
        onDismiss?()
    }
}


extension BetterPreviewController: QLPreviewControllerDataSource {

    func numberOfPreviewItems(in _: QLPreviewController) -> Int {
        return urls.count
    }

    func previewController(_: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return urls[index] as QLPreviewItem
    }
}

extension BetterPreviewController: UIAdaptivePresentationControllerDelegate {

    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {

    }
}

import QuickLook
import UIKit
import DcCore

class PreviewController: QLPreviewController {

    enum PreviewType {
        case single(URL)
        case multi([Int], Int) // msgIds, index
    }

    let previewType: PreviewType

    /*
    var msgIds: [Int] = []
    var url: URL?
    */

    var customTitle: String?

    private lazy var doneButtonItem: UIBarButtonItem = {
        let button = UIBarButtonItem(title: String.localized("done"), style: .done, target: self, action: #selector(doneButtonPressed(_:)))
        return button
    }()

    init(type: PreviewType) {
        self.previewType = type
        super.init(nibName: nil, bundle: nil)
    }

    /*
    convenience init(url: URL) {
        self.init(currentIndex: 0, msgIds: [])
        self.url = url
    }

    init(currentIndex: Int, msgIds: [Int]) {
        self.msgIds = msgIds
        super.init(nibName: nil, bundle: nil)
        dataSource = self
        currentPreviewItemIndex = currentIndex
    }
    */

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if navigationController?.isBeingPresented ?? false {
            /* QLPreviewController comes with a done-button by default. But if is embedded in UINavigationContrller we need to set a done-button manually.
            */
            navigationItem.leftBarButtonItem = doneButtonItem
        }
    }

    // MARK: - actions
    @objc private func doneButtonPressed(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension PreviewController: QLPreviewControllerDataSource {

    func numberOfPreviewItems(in _: QLPreviewController) -> Int {
        switch previewType {
        case .single:
            return 1
        case .multi(let msgIds, _):
            return msgIds.count
        }
    }

    func previewController(_: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        switch previewType {
        case .single(let url):
            return PreviewItem(url: url, title: self.customTitle)
        case .multi(let msgIds, let index):
            let msg = DcMsg(id: msgIds[index])
            return PreviewItem(url: msg.fileURL, title: self.customTitle)
        }
    }
}

// needed to prevent showing url-path in PreviewController's title (only relevant if url.count == 1)
class PreviewItem: NSObject, QLPreviewItem {
    var previewItemURL: URL?
    var previewItemTitle: String?

    init(url: URL?, title: String?) {
        self.previewItemURL = url
        self.previewItemTitle = title ?? ""
    }
}

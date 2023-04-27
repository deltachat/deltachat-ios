import QuickLook
import UIKit
import DcCore

class PreviewController: QLPreviewController {
    enum PreviewType {
        case single(URL)
        case multi([Int], Int) // msgIds, index
    }

    let previewType: PreviewType

    var customTitle: String?
    var dcContext: DcContext

    init(dcContext: DcContext, type: PreviewType) {
        self.previewType = type
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        dataSource = self
        switch type {
        case .multi(_, let currentIndex):
            currentPreviewItemIndex = currentIndex
        case .single:
            currentPreviewItemIndex = 0
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        case .multi(let msgIds, _):
            let msg = dcContext.getMessage(id: msgIds[index])
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

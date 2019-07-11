import QuickLook
import UIKit

class PreviewController: QLPreviewControllerDataSource {
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

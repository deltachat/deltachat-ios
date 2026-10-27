import UIKit
import WebKit
import DcCore

class MapViewController: WebxdcViewController {
    private let isGlobalMap: Bool

    init(dcContext: DcContext, chatId: Int) {
        isGlobalMap = chatId == 0
        var webxdcInstanceId = dcContext.initWebxdcIntegration(for: chatId)
        if webxdcInstanceId == 0 {
            if let mapsXdc = Bundle.main.url(forResource: "maps", withExtension: "xdc", subdirectory: "Assets") {
                dcContext.setWebxdcIntegration(filepath: mapsXdc.path)
                webxdcInstanceId = dcContext.initWebxdcIntegration(for: chatId)
            }
        }
        super.init(dcContext: dcContext, messageId: webxdcInstanceId)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = nil
    }

    override func refreshWebxdcInfo() {
        super.refreshWebxdcInfo()
        title = String.localized(isGlobalMap ? "menu_show_global_map" : "locations")
    }
}

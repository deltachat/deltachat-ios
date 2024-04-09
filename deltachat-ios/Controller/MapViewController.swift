import UIKit
import WebKit
import DcCore

class MapViewController: WebxdcViewController {
    private var locationChangedObserver: NSObjectProtocol?
    private let isGlobalMap: Bool

    init(dcContext: DcContext, chatId: Int) {
        isGlobalMap = chatId == 0
        var msgId = dcContext.initWebxdcIntegration(DC_INTEGRATION_MAPS, for: chatId)
        if msgId == 0 {
            if let path = Bundle.main.url(forResource: "maps", withExtension: "xdc", subdirectory: "Assets") {
                let msg = dcContext.newMessage(viewType: DC_MSG_WEBXDC)
                msg.setFile(filepath: path.path)
                msg.setDefaultWebxdcIntegration()
                dcContext.sendMessage(chatId: dcContext.createChatByContactId(contactId: Int(DC_CONTACT_ID_SELF)), message: msg)
                msgId = dcContext.initWebxdcIntegration(DC_INTEGRATION_MAPS, for: chatId)
            }
        }
        super.init(dcContext: dcContext, messageId: msgId)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = nil
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            removeObservers()
        } else {
            addObservers()
        }
    }

    override func refreshWebxdcInfo() {
        super.refreshWebxdcInfo()
        title = String.localized(isGlobalMap ? "menu_show_global_map" : "locations")
    }

    // MARK: - setup

    private func addObservers() {
        locationChangedObserver = NotificationCenter.default.addObserver(forName: eventLocationChanged, object: nil, queue: nil) { [weak self]_ in
            self?.updateWebxdc()
        }
    }

    private func removeObservers() {
        if let locationChangedObserver = self.locationChangedObserver {
            NotificationCenter.default.removeObserver(locationChangedObserver)
        }
    }
}

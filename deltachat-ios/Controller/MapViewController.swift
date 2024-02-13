import UIKit
import WebKit
import DcCore

class MapViewController: WebxdcViewController {
    private let chatId: Int
    private var locationChangedObserver: NSObjectProtocol?
    private var lastLocationId: Int = 0

    init(dcContext: DcContext, chatId: Int) {
        self.chatId = chatId
        let msgIdConfigKey = "maps_webxdc_msg_id16."
        var msgId = UserDefaults.standard.integer(forKey: msgIdConfigKey + String(dcContext.id))
        if !dcContext.msgExists(id: msgId) {
            if let path = Bundle.main.url(forResource: "maps", withExtension: "xdc", subdirectory: "Assets") {
                let chatId = dcContext.createChatByContactId(contactId: Int(DC_CONTACT_ID_SELF))
                let msg = dcContext.newMessage(viewType: DC_MSG_WEBXDC)
                msg.setFile(filepath: path.path)
                msg.text =  "Thanks for trying out the experimental feature 🧪 \"Location streaming\"\n\n"
                        +   "This message is needed temporarily for development and debugging. "
                        +   "To see locations, POIs and tracks on the map, "
                        +   "do not open it here but from \"All Media\" or from chat \"Profiles\".\n\n"
                        +   "If you want to quit the experimental feature, "
                        +   "you can disable it at \"Settings / Advanced\" and delete this message."
                msgId = dcContext.sendMessage(chatId: chatId, message: msg)
                UserDefaults.standard.setValue(msgId, forKey: msgIdConfigKey + String(dcContext.id))
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
        title = String.localized(chatId == 0 ? "menu_show_global_map" : "locations")
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


    // MARK: - handle updates

    override func sendWebxdcStatusUpdate(payload: String, description: String) -> Bool {
        guard let data: Data = payload.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: AnyObject],
              let payload = dict["payload"] as? [String: AnyObject] else {
           return false
        }

        let msg = dcContext.newMessage(viewType: DC_MSG_TEXT)
        msg.text = payload["label"] as? String ?? "ErrLabel"
        msg.setLocation(lat: payload["lat"] as? Double ?? 0.0, lng: payload["lng"] as? Double ?? 0.0)
        return dcContext.sendMessage(chatId: chatId == 0 ? dcContext.createChatByContactId(contactId: Int(DC_CONTACT_ID_SELF)) : chatId, message: msg) != 0
    }

    override func getWebxdcStatusUpdates(lastKnownSerial: Int) -> String {
        let end = Int64(Date().timeIntervalSince1970)
        let begin = end - 24*60*60
        let (json, maxLocationId) = dcContext.getLocations(chatId: chatId, timestampBegin: begin, timestampEnd: 0, lastLocationId: lastLocationId)
        lastLocationId = max(maxLocationId, lastLocationId)
        UIPasteboard.general.string = json // TODO: remove this line, useful for debugging to get JSON out
        return json
    }
}

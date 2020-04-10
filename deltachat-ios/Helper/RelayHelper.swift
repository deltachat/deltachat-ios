import Foundation
import DcCore

class RelayHelper {
    static var sharedInstance: RelayHelper = RelayHelper()
    private static var dcContext: DcContext?
    var messageId: Int?

    private init() {
        guard RelayHelper.dcContext != nil else {
            fatalError("Error - you must call RelayHelper.setup() before accessing RelayHelper.shared")
        }
    }

    class func setup(_ dcContext: DcContext) {
        RelayHelper.dcContext = dcContext
    }

    func setForwardMessage(messageId: Int) {
        self.messageId = messageId
    }

    func isForwarding() -> Bool {
        return messageId != nil
    }

    func forward(to chat: Int) {
        if let messageId = self.messageId {
            RelayHelper.dcContext?.forwardMessage(with: messageId, to: chat)
        }
        self.messageId = nil
    }

    func cancel() {
        messageId = nil
    }
}

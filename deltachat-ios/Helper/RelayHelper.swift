import Foundation
import DcCore

class RelayHelper {
    static var sharedInstance: RelayHelper = RelayHelper()
    private static var dcContext: DcContext?
    var messageIds: [Int]?

    private init() {
        guard RelayHelper.dcContext != nil else {
            fatalError("Error - you must call RelayHelper.setup() before accessing RelayHelper.shared")
        }
    }

    class func setup(_ dcContext: DcContext) -> RelayHelper {
        RelayHelper.dcContext = dcContext
        return sharedInstance
    }

    func setForwardMessage(messageId: Int) {
        self.messageIds = [messageId]
    }

    func setForwardMessages(messageIds: [Int]) {
        self.messageIds = messageIds
    }

    func isForwarding() -> Bool {
        return !(messageIds?.isEmpty ?? true)
    }

    func forward(to chat: Int) {
        if let messageIds = self.messageIds {
            RelayHelper.dcContext?.forwardMessages(with: messageIds, to: chat)
        }
        self.messageIds = nil
    }

    func cancel() {
        messageIds = nil
    }
}

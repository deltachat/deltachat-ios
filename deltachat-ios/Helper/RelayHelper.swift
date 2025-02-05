import Foundation
import DcCore

class RelayHelper {
    static var shared: RelayHelper = RelayHelper()
    private static var dcContext: DcContext?

    var dialogTitle: String = ""

    var forwardIds: [Int]?
    var forwardText: String?
    var forwardFileData: Data?
    var forwardFileName: String?
    var forwardVCardData: Data?

    var mailtoDraft: String = ""
    var mailtoAddress: String?
    var askToChatWithMailto: Bool = true

    private init() {
        guard RelayHelper.dcContext != nil else {
            fatalError("Error - you must call RelayHelper.setup() before accessing RelayHelper.shared")
        }
    }

    class func setup(_ dcContext: DcContext) -> RelayHelper {
        RelayHelper.dcContext = dcContext
        return shared
    }


    // forwarding messages

    func setForwardVCard(vcardData: Data) {
        finishRelaying()
        self.dialogTitle = String.localized("chat_share_with_title")
        self.forwardVCardData = vcardData
    }

    func setForwardMessage(dialogTitle: String, text: String?, fileData: Data?, fileName: String?) {
        finishRelaying()
        self.dialogTitle = dialogTitle
        self.forwardText = text
        self.forwardFileData = fileData
        self.forwardFileName = fileName
    }

    func setForwardMessage(messageId: Int) {
        finishRelaying()
        self.dialogTitle = String.localized("forward_to")
        self.forwardIds = [messageId]
    }

    func setForwardMessages(messageIds: [Int]) {
        finishRelaying()
        self.dialogTitle = String.localized("forward_to")
        if !messageIds.isEmpty {
            self.forwardIds = messageIds
        }
    }

    func isForwarding() -> Bool {
        return forwardIds != nil || forwardText != nil || forwardFileData != nil || forwardVCardData != nil
    }

    func forwardIdsAndFinishRelaying(to chat: Int) {
        if let messageIds = self.forwardIds {
            RelayHelper.dcContext?.forwardMessages(with: messageIds, to: chat)
        }
        finishRelaying()
    }

    func finishRelaying() {
        dialogTitle = ""
        forwardIds = nil
        forwardText = nil
        forwardFileData = nil
        forwardFileName = nil
        forwardVCardData = nil
        mailtoDraft = ""
        mailtoAddress = nil
        askToChatWithMailto = true
    }


    // mailto: handling

    func isMailtoHandling() -> Bool {
        return !mailtoDraft.isEmpty || mailtoAddress != nil
    }

    func splitString(_ value: String) -> [String] {
        return value.split(separator: ",").map(String.init)
    }

    func parseMailtoUrl(_ url: URL) -> Bool {
        if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            var subject: String = ""
            var body: String = ""
            let queryItems = urlComponents.queryItems ?? []
            for queryItem in queryItems {
                guard let value = queryItem.value else {
                    continue
                }
                switch queryItem.name {
                case "body":
                    body = value
                case "subject":
                    subject = value
                default:
                    break
                }
            }

            if !subject.isEmpty {
                mailtoDraft = subject
                if !body.isEmpty {
                    mailtoDraft += "\n\n\(body)"
                }
            } else if !body.isEmpty {
                mailtoDraft = body
            }

            if !urlComponents.path.isEmpty {
                mailtoAddress = splitString(urlComponents.path)[0] // we currently only allow 1 receipient
            }
            return mailtoAddress != nil || !mailtoDraft.isEmpty
        }
        return false
    }
}

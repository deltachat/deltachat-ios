import Foundation
import DcCore

class RelayHelper {
    static var shared: RelayHelper = RelayHelper()
    private static var dcContext: DcContext?
    var messageIds: [Int]?

    var mailtoDraft: String = ""
    var mailtoAddress: String?

    private init() {
        guard RelayHelper.dcContext != nil else {
            fatalError("Error - you must call RelayHelper.setup() before accessing RelayHelper.shared")
        }
    }

    class func setup(_ dcContext: DcContext) -> RelayHelper {
        RelayHelper.dcContext = dcContext
        return shared
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

    func isMailtoHandling() -> Bool {
        return !mailtoDraft.isEmpty || mailtoAddress != nil
    }

    func finishMailto() {
        mailtoDraft = ""
        mailtoAddress = nil
    }


    func splitString(_ value: String) -> [String] {
        return value.split(separator: ",").map(String.init)
    }

    /**
            returns true if parsing was successful
     */
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

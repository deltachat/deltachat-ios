import Foundation
import DcCore

enum RelayData {
    case forwardMessages(srcContextId: Int, ids: [Int])
    case forwardMessage(text: String?, fileData: Data?, fileName: String?)
    case forwardVCard(Data)
    case mailto(address: String, draft: String?)
    case share([DcMsg])
}

class RelayHelper {
    static var shared: RelayHelper = RelayHelper()
    var dialogTitle: String = ""
    var data: RelayData? {
        didSet {
            NotificationCenter.default.post(name: Event.relayHelperDidChange, object: nil)
        }
    }

    // forwarding messages

    func setForwardVCard(vcardData: Data) {
        finishRelaying()
        self.dialogTitle = String.localized("chat_share_with_title")
        self.data = .forwardVCard(vcardData)
    }

    func setForwardMessage(dialogTitle: String, text: String?, fileData: Data?, fileName: String?) {
        finishRelaying()
        self.dialogTitle = dialogTitle
        self.data = .forwardMessage(text: text, fileData: fileData, fileName: fileName)
    }

    func setForwardMessages(messageIds: [Int]) {
        finishRelaying()
        self.dialogTitle = String.localized("forward_to")
        self.data = .forwardMessages(srcContextId: DcAccounts.shared.getSelected().id, ids: messageIds)
    }
    
    func setShareMessages(messages: [DcMsg]) {
        finishRelaying()
        self.dialogTitle = String.localized("chat_share_with_title")
        self.data = .share(messages)
    }

    func isForwarding() -> Bool {
        switch data {
        case .forwardMessage, .forwardVCard, .forwardMessages: true
        default: false
        }
    }
    
    func isSharing() -> Bool {
        if case .share = data { true } else { false }
    }
    
    func shareAndFinishRelaying(to chatId: Int) {
        if case .share(let messages) = data {
            let dcContext = DcAccounts.shared.getSelected()
            for msg in messages {
                dcContext.sendMessage(chatId: chatId, message: msg)
            }
            DcUtils.donateSendMessageIntent(
                context: dcContext,
                chatId: chatId,
                chatAvatar: dcContext.getChat(chatId: chatId).profileImage
            )
        }
        // Remove temp files in share extension dir
        try? FileManager.default.removeItem(at: shareExtensionDirectory)
        finishRelaying()
    }

    func forwardIdsAndFinishRelaying(to chatId: Int) {
        if case .forwardMessages(let srcContextId, let messageIds) = data {
            let srcContext = DcAccounts.shared.get(id: srcContextId)
            let dcContext = DcAccounts.shared.getSelected()

            if srcContext.id != dcContext.id {
                srcContext.forwardMessagesToAccount(messageIds: messageIds, destContextId: dcContext.id, destChatId: chatId)
            } else {
                if dcContext.getChat(chatId: chatId).isSelfTalk {
                    for id in messageIds {
                        let curr = dcContext.getMessage(id: id)
                        if curr.canSave && curr.savedMessageId == 0 && curr.chatId != chatId {
                            dcContext.saveMessages(with: [curr.id])
                        } else {
                            dcContext.forwardMessages(with: [curr.id], to: chatId)
                        }
                    }
                } else {
                    dcContext.forwardMessages(with: messageIds, to: chatId)
                }
            }
        }
        finishRelaying()
    }

    func finishRelaying() {
        dialogTitle = ""
        data = nil
    }

    // mailto: handling

    func isMailtoHandling() -> Bool {
        if case .mailto = data { true } else { false }
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
            var draft: String?
            if !subject.isEmpty {
                draft = subject
                if !body.isEmpty {
                    draft?.append("\n\n\(body)")
                }
            } else if !body.isEmpty {
                draft = body
            }
            // we currently only allow 1 recipient
            if !urlComponents.path.isEmpty, let address = splitString(urlComponents.path).first {
                data = .mailto(address: address, draft: draft)
                return true
            }
        }
        return false
    }
}

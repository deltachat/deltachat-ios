import Foundation
import UIKit
import DcCore

public class DraftModel {
    var quoteMessage: DcMsg?
    var quoteText: String?
    var text: String?
    var attachment: String?
    var attachmentMimeType: String?
    var viewType: Int32?
    let chatId: Int

    public init(chatId: Int) {
        self.chatId = chatId
    }

    public func parse(draftMsg: DcMsg?) {
        text = draftMsg?.text
        quoteText = draftMsg?.quoteText
        quoteMessage = draftMsg?.quoteMessage
        attachment = draftMsg?.fileURL?.relativePath
        if let viewType = draftMsg?.type {
            self.viewType = Int32(viewType)
        }
        attachmentMimeType = draftMsg?.filemime
    }

    public func setQuote(quotedMsg: DcMsg?) {
        if let quotedMsg = quotedMsg {
            // create a temporary draft to get the correct quoteText
            let draftMessage = DcMsg(viewType: DC_MSG_TEXT)
            draftMessage.quoteMessage = quotedMsg
            self.quoteText = draftMessage.quoteText
            self.quoteMessage = quotedMsg
        } else {
            self.quoteText = nil
            self.quoteMessage = nil
        }
    }

    public func setAttachment(viewType: Int32?, path: String?, mimetype: String? = nil) {
        attachment = path
        self.viewType = viewType
        attachmentMimeType = mimetype
    }

    public func save(context: DcContext) {
        if text == nil && quoteMessage == nil {
            context.setDraft(chatId: chatId, message: nil)
            return
        }

        let draftMessage = DcMsg(viewType: viewType ?? DC_MSG_TEXT)
        draftMessage.text = text
        if quoteMessage != nil {
            draftMessage.quoteMessage = quoteMessage
        }
        if attachment != nil {
            draftMessage.setFile(filepath: attachment, mimeType: attachmentMimeType)
        }
        context.setDraft(chatId: chatId, message: draftMessage)
    }

    public func canSend() -> Bool {
        return !(text?.isEmpty ?? true) || attachment != nil
    }
}

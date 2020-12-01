import Foundation
import UIKit
import DcCore

public class DraftModel {
    var quoteMessage: DcMsg?
    var quoteText: String?
    var draftText: String?
    var draftAttachment: URL?
    var draftAttachmentMimeType: String?
    var draftViewType: Int32?
    let chatId: Int

    public init(chatId: Int) {
        self.chatId = chatId
    }

    public func parse(draftMsg: DcMsg?) {
        draftText = draftMsg?.text
        quoteText = draftMsg?.quoteText
        quoteMessage = draftMsg?.quoteMessage
        draftAttachment = draftMsg?.fileURL
        if let viewType = draftMsg?.type {
            draftViewType = Int32(viewType)
        }
        draftAttachmentMimeType = draftMsg?.filemime
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

    public func setAttachment(viewType: Int32?, path: URL?, mimetype: String? = nil) {
        draftAttachment = path
        draftViewType = viewType
        draftAttachmentMimeType = mimetype
    }

    public func save(context: DcContext) {
        if draftText == nil && quoteMessage == nil {
            context.setDraft(chatId: chatId, message: nil)
            return
        }

        let draftMessage = DcMsg(viewType: draftViewType ?? DC_MSG_TEXT)
        draftMessage.text = draftText
        if quoteMessage != nil {
            draftMessage.quoteMessage = quoteMessage
        }
        if draftAttachment != nil {
            draftMessage.setFile(filepath: draftAttachment?.absoluteString, mimeType: draftAttachmentMimeType)
        }
        context.setDraft(chatId: chatId, message: draftMessage)
    }

    public func canSend() -> Bool {
        return !(draftText?.isEmpty ?? true) || draftAttachment != nil
    }
}

import Foundation
import UIKit
import DcCore

public class DraftModel {
    var quoteMessage: DcMsg?
    var quoteText: String?
    var draftText: String?
    let chatId: Int

    public init(chatId: Int) {
        self.chatId = chatId
    }

    public func parse(draftMsg: DcMsg?) {
        draftText = draftMsg?.text
        quoteText = draftMsg?.quoteText
        quoteMessage = draftMsg?.quoteMessage
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

    public func save(context: DcContext) {
        if draftText == nil && quoteMessage == nil {
            context.setDraft(chatId: chatId, message: nil)
            return
        }

        let draftMessage = DcMsg(viewType: DC_MSG_TEXT)
        draftMessage.text = draftText
        if quoteMessage != nil {
            draftMessage.quoteMessage = quoteMessage
        }
        context.setDraft(chatId: chatId, message: draftMessage)
    }
}

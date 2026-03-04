import Foundation
import UIKit
import DcCore

public class DraftModel: ObservableObject {
    @Published var draftMsg: DcMsg?
    let dcContext: DcContext
    @Published var text: String = ""
    let chatId: Int
    var isEditing: Bool = false // multi edit
    @Published var sendEditRequestFor: Int?
    var quoteMessage: DcMsg? {
        return draftMsg?.quoteMessage
    }
    var quoteText: String? {
        return draftMsg?.quoteText
    }
    var attachment: String? {
        return draftMsg?.fileURL?.relativePath
    }
    var attachmentMimeType: String? {
        return draftMsg?.filemime
    }
    var viewType: Int32? {
        return draftMsg?.type
    }
    private var trimmedText: String {
        text.replacingOccurrences(of: "\u{FFFC}", with: "", options: .literal, range: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public init(dcContext: DcContext, chatId: Int) {
        self.chatId = chatId
        self.dcContext = dcContext
    }

    public func parse(draftMsg: DcMsg?) {
        self.draftMsg = draftMsg
        text = draftMsg?.text ?? ""
    }

    public func setQuote(quotedMsg: DcMsg?) {
        if draftMsg == nil && quotedMsg != nil {
            draftMsg = dcContext.newMessage(viewType: DC_MSG_TEXT)
        }
        draftMsg?.quoteMessage = quotedMsg
        publishDraftMsgChange()
        sendEditRequestFor = nil
    }

    public func setAttachment(viewType: Int32?, path: String?, mimetype: String? = nil) {
        sendEditRequestFor = nil
        let quoteMsg = draftMsg?.quoteMessage
        draftMsg = dcContext.newMessage(viewType: viewType ?? DC_MSG_TEXT)
        draftMsg?.quoteMessage = quoteMsg
        draftMsg?.setFile(filepath: path, mimeType: mimetype)
        publishDraftMsgChange()
        save(context: dcContext)
    }

    public func clearAttachment() {
        sendEditRequestFor = nil
        let quoteMsg = draftMsg?.quoteMessage
        if !trimmedText.isEmpty || quoteMsg != nil {
            draftMsg = dcContext.newMessage(viewType: DC_MSG_TEXT)
            draftMsg?.quoteMessage = quoteMsg
            publishDraftMsgChange()
            save(context: dcContext)
        } else {
            draftMsg = nil
            dcContext.setDraft(chatId: chatId, message: nil)
        }
    }

    public func save(context: DcContext) {
        guard sendEditRequestFor == nil else { return }

        guard !trimmedText.isEmpty || quoteMessage != nil || attachment != nil else {
            self.clear()
            return
        }

        if draftMsg == nil {
            draftMsg = dcContext.newMessage(viewType: DC_MSG_TEXT)
        }
        draftMsg?.text = text // not using trimmedText because draft should maintain trailing newlines
        context.setDraft(chatId: chatId, message: draftMsg)
    }

    public func canSend() -> Bool {
        return !trimmedText.isEmpty || attachment != nil
    }

    public func clear() {
        text = ""
        draftMsg = nil
        sendEditRequestFor = nil
        dcContext.setDraft(chatId: chatId, message: nil)
    }

    public func send() {
        guard canSend() else { return }
        if let sendEditRequestFor {
            dcContext.sendEditRequest(msgId: sendEditRequestFor, newText: text)
            // doResignFirstResponder = true // TODO: Can we move focusstate into the model? otherwise just end editing in general
        } else {
            let draftMsg = draftMsg ?? dcContext.newMessage(viewType: DC_MSG_TEXT)
            draftMsg.text = trimmedText
            dcContext.sendMessage(chatId: chatId, message: draftMsg)
        }
        clear()
    }

    private func publishDraftMsgChange() {
        draftMsg = draftMsg
    }
}

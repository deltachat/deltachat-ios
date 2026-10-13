import Foundation
import DcCore

protocol AvatarCellViewModel {
    var dcContext: DcContext { get }
    var type: CellModel { get }
    var title: String { get }
    var titleHighlightRanges: [NSRange] { get }
    var subtitle: String { get }
    var subtitleHighlightRanges: [NSRange] { get }
}

enum CellModel {
    case contact(ContactCellData)
    case chat(ChatCellData)
    case profile
}

struct ContactCellData {
    let contactId: Int
    let chatId: Int?
}

struct ChatCellData {
    let chatId: Int
    let highlightMsgId: Int?
    let summary: DcLot
    let unreadMessages: Int
}

class ContactCellViewModel: AvatarCellViewModel {

    private let contact: DcContact
    let dcContext: DcContext

    var type: CellModel
    var title: String {
        return contact.displayName
    }
    var subtitle: String {
        return contact.getSubtitle(oldOnly: true) ?? ""
    }

    var avartarTitle: String {
        return DcUtils.getInitials(inputName: title)
    }

    var titleHighlightRanges: [NSRange]
    var subtitleHighlightRanges: [NSRange]

    init(dcContext: DcContext, contactData: ContactCellData, titleHighlightRanges: [NSRange] = [], subtitleHighlightRanges: [NSRange] = []) {
        type = CellModel.contact(contactData)
        self.titleHighlightRanges = titleHighlightRanges
        self.subtitleHighlightRanges = subtitleHighlightRanges
        self.contact = dcContext.getContact(id: contactData.contactId)
        self.dcContext = dcContext
    }
}

class ProfileViewModel: AvatarCellViewModel {

    let dcContext: DcContext
    var type: CellModel {
        return CellModel.profile
    }

    var title: String

    private let contact: DcContact

    var titleHighlightRanges: [NSRange] {
        return []
    }

    var subtitle: String

    var subtitleHighlightRanges: [NSRange] {
        return []
    }

    init(context: DcContext) {
        self.dcContext = context
        contact = context.getContact(id: Int(DC_CONTACT_ID_SELF))
        title = context.displayname ?? String.localized("pref_your_name")

        if let bio = context.selfstatus {
            subtitle = bio.replacingOccurrences(of: "\\r\\n|\\n", with: " ", options: .regularExpression)
        } else {
            subtitle = String.localized("pref_default_status_label")
        }
    }
}

class ChatCellViewModel: AvatarCellViewModel {

    private let chat: DcChat
    let dcContext: DcContext

    private var summary: DcLot

    var type: CellModel
    var title: String {
        return chat.name
    }

    var subtitle: String {
        let result1 = summary.text1 ?? ""
        let result2 = summary.text2 ?? ""
        let result: String
        if !result1.isEmpty, !result2.isEmpty {
            result = "\(result1): \(result2)"
        } else {
            result = "\(result1)\(result2)"
        }
        return result
    }

    var titleHighlightRanges: [NSRange]
    var subtitleHighlightRanges: [NSRange]

    init(dcContext: DcContext, chatData: ChatCellData, titleHighlightRanges: [NSRange] = [], subtitleHighlightRanges: [NSRange] = []) {
        self.type = CellModel.chat(chatData)
        self.titleHighlightRanges = titleHighlightRanges
        self.subtitleHighlightRanges = subtitleHighlightRanges
        self.summary = chatData.summary
        self.chat = dcContext.getChat(chatId: chatData.chatId)
        self.dcContext = dcContext
    }
}

extension ContactCellViewModel {
    static func make(contactId: Int, searchText: String? = nil, dcContext: DcContext) -> ContactCellViewModel {
        let contact = dcContext.getContact(id: contactId)
        let nameRanges = contact.displayName.nsRanges(of: searchText ?? "")
        let emailRanges = contact.email.nsRanges(of: searchText ?? "")
        let chatId: Int? = dcContext.getChatIdByContactIdOld(contactId)
            // contact contains searchText
        let viewModel = ContactCellViewModel(
            dcContext: dcContext,
            contactData: ContactCellData(
                contactId: contactId,
                chatId: chatId
            ),
            titleHighlightRanges: nameRanges,
            subtitleHighlightRanges: emailRanges
        )
        return viewModel
    }
}

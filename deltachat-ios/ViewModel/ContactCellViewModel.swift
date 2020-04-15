import Foundation
import DcCore

protocol AvatarCellViewModel {
    var type: CellModel { get }
    var title: String { get }
    var titleHighlightIndexes: [Int] { get }
    var subtitle: String { get }
    var subtitleHighlightIndexes: [Int] { get }
}

enum CellModel {
    case contact(ContactCellData)
    case chat(ChatCellData)
    case deaddrop(DeaddropCellData)
}

struct ContactCellData {
    let contactId: Int
    let chatId: Int?
}

struct ChatCellData {
    let chatId: Int
    let summary: DcLot
    let unreadMessages: Int
}

struct DeaddropCellData {
    let chatId: Int
    let msgId: Int
    let summary: DcLot
}

class ContactCellViewModel: AvatarCellViewModel {

    private let contact: DcContact

    var type: CellModel
    var title: String {
        return contact.displayName
    }
    var subtitle: String {
        return contact.email
    }

    var avartarTitle: String {
        return Utils.getInitials(inputName: title)
    }

    var titleHighlightIndexes: [Int]
    var subtitleHighlightIndexes: [Int]

    init(contactData: ContactCellData, titleHighlightIndexes: [Int] = [], subtitleHighlightIndexes: [Int] = []) {
        type = CellModel.contact(contactData)
        self.titleHighlightIndexes = titleHighlightIndexes
        self.subtitleHighlightIndexes = subtitleHighlightIndexes
        self.contact = DcContact(id: contactData.contactId)
    }
}

class ChatCellViewModel: AvatarCellViewModel {

    private let chat: DcChat

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

    var titleHighlightIndexes: [Int]
    var subtitleHighlightIndexes: [Int]

    init(dcContext: DcContext, chatData: ChatCellData, titleHighlightIndexes: [Int] = [], subtitleHighlightIndexes: [Int] = []) {
        self.type = CellModel.chat(chatData)
        self.titleHighlightIndexes = titleHighlightIndexes
        self.subtitleHighlightIndexes = subtitleHighlightIndexes
        self.summary = chatData.summary
        self.chat = dcContext.getChat(chatId: chatData.chatId)
    }

    init(dcContext: DcContext, deaddropCellData cellData: DeaddropCellData) {
        self.type = CellModel.deaddrop(cellData)
        self.titleHighlightIndexes = []
        self.subtitleHighlightIndexes = []
        self.chat = dcContext.getChat(chatId: cellData.chatId)
        self.summary = cellData.summary
    }
}

extension ContactCellViewModel {
    static func make(contactId: Int, searchText: String?, dcContext: DcContext) -> ContactCellViewModel {
        let contact = DcContact(id: contactId)
        let nameIndexes = contact.displayName.containsExact(subSequence: searchText)
        let emailIndexes = contact.email.containsExact(subSequence: searchText)
        let chatId: Int? = dcContext.getChatIdByContactId(contactId)
            // contact contains searchText
        let viewModel = ContactCellViewModel(
            contactData: ContactCellData(
                contactId: contact.id,
                chatId: chatId
            ),
            titleHighlightIndexes: nameIndexes,
            subtitleHighlightIndexes: emailIndexes
        )
        return viewModel
    }
}

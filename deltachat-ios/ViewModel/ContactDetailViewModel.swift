import UIKit
import DcCore

protocol ContactDetailViewModelProtocol {
    var context: DcContext { get }
    var contactId: Int { get }
    var contact: DcContact { get }
    var numberOfSections: Int { get }
    var chatIsArchived: Bool { get }
    func numberOfRowsInSection(_ : Int) -> Int
    func typeFor(section: Int) -> ContactDetailViewModel.ProfileSections
    func chatActionFor(row: Int) -> ContactDetailViewModel.ChatAction
    func attachmentActionFor(row: Int) -> ContactDetailViewModel.AttachmentAction
    func update(sharedChatCell: ContactCell, row index: Int)
    func getSharedChatIdAt(indexPath: IndexPath) -> Int
    func titleFor(section: Int) -> String?
    func toggleArchiveChat() -> Bool // returns true if chat is archived after action
}

class ContactDetailViewModel: ContactDetailViewModelProtocol {

    let context: DcContext

    enum ProfileSections {
        case startChat
        case attachments
        case sharedChats
        case chatActions //  archive chat, block chat, delete chats
    }

    enum ChatAction {
        case archiveChat
        case blockChat
        case deleteChat
    }

    enum AttachmentAction {
        case gallery
        case documents
    }

    var contactId: Int

    var contact: DcContact {
        return DcContact(id: contactId)
    }

    private let chatId: Int?
    private let sharedChats: DcChatlist
    private var sections: [ProfileSections] = []
    private var chatActions: [ChatAction] = [] // chatDetail: archive, block, delete - else: block
    private var attachmentActions: [AttachmentAction] = [.gallery, .documents]

    /// if chatId is nil this is a contact detail with 'start chat'-option
    init(contactId: Int, chatId: Int?, context: DcContext) {
        self.context = context
        self.contactId = contactId
        self.chatId = chatId
        self.sharedChats = context.getChatlist(flags: 0, queryString: nil, queryId: contactId)

        sections.append(.attachments)
        sections.append(.startChat)
        if sharedChats.length > 0 {
            sections.append(.sharedChats)
        }
        sections.append(.chatActions)

        if chatId != nil {
            chatActions = [.archiveChat, .blockChat, .deleteChat]
        } else {
            chatActions = [.blockChat]
        }
    }

    func typeFor(section: Int) -> ContactDetailViewModel.ProfileSections {
        return sections[section]
    }

    func chatActionFor(row: Int) -> ContactDetailViewModel.ChatAction {
        return chatActions[row]
    }

    func attachmentActionFor(row: Int) -> ContactDetailViewModel.AttachmentAction {
        return attachmentActions[row]
    }

    var chatIsArchived: Bool {
        guard let chatId = chatId else {
           // safe_fatalError("This is a ContactDetail view with no chat id")
            return false
        }
        return context.getChat(chatId: chatId).isArchived
    }

    var numberOfSections: Int {
        return sections.count
    }

    func numberOfRowsInSection(_ section: Int) -> Int {
        switch sections[section] {
        case .attachments: return 2
        case .sharedChats: return sharedChats.length
        case .startChat: return 1
        case .chatActions: return chatActions.count
        }
    }

    func getSharedChatIdAt(indexPath: IndexPath) -> Int {
        let index = indexPath.row
        // assert(sections[indexPath.section] == .sharedChats)
        return sharedChats.getChatId(index: index)
    }

    func update(sharedChatCell cell: ContactCell, row index: Int) {
        let chatId = sharedChats.getChatId(index: index)
        let summary = sharedChats.getSummary(index: index)
        let unreadMessages = context.getUnreadMessages(chatId: chatId)

        let cellData = ChatCellData(chatId: chatId, summary: summary, unreadMessages: unreadMessages)
        let cellViewModel = ChatCellViewModel(dcContext: context, chatData: cellData)
        cell.updateCell(cellViewModel: cellViewModel)
    }

    func titleFor(section: Int) -> String? {
        if sections[section] == .sharedChats {
            return String.localized("profile_shared_chats")
        }
        return nil
    }

    func toggleArchiveChat() -> Bool {
        guard let chatId = chatId else {
            safe_fatalError("there is no chatId - you are probably are calling this from ContactDetail - this should be only called from ChatDetail")
            return false
        }
        context.archiveChat(chatId: chatId, archive: !chatIsArchived)
        return chatIsArchived
    }
}

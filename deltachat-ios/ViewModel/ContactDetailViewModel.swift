import UIKit
import DcCore

class ContactDetailViewModel {

    let context: DcContext

    enum ProfileSections {
        case startChat
        case attachments
        case sharedChats
        case chatActions //  archive chat, block chat, delete chats
    }

    enum ChatAction {
        case muteChat
        case archiveChat
        case blockContact
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

    let chatId: Int
    private let sharedChats: DcChatlist
    private var sections: [ProfileSections] = []
    private var chatActions: [ChatAction] = []
    private var attachmentActions: [AttachmentAction] = [.gallery, .documents]

    init(dcContext: DcContext, contactId: Int) {
        self.context = dcContext
        self.contactId = contactId
        self.chatId = dcContext.getChatIdByContactId(contactId: contactId)
        self.sharedChats = context.getChatlist(flags: 0, queryString: nil, queryId: contactId)

        sections.append(.attachments)
        sections.append(.startChat)
        if sharedChats.length > 0 {
            sections.append(.sharedChats)
        }
        sections.append(.chatActions)

        if chatId != 0 {
            chatActions = [.muteChat, .archiveChat, .blockContact, .deleteChat]
        } else {
            chatActions = [.blockContact]
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
        return chatId != 0 && context.getChat(chatId: chatId).isArchived
    }

    var chatIsMuted: Bool {
        return chatId != 0 && context.getChat(chatId: chatId).isMuted
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

    // returns true if chat is archived after action
    func toggleArchiveChat() -> Bool {
        if chatId == 0 {
            safe_fatalError("there is no chatId - you are probably are calling this from ContactDetail - this should be only called from ChatDetail")
            return false
        }
        context.archiveChat(chatId: chatId, archive: !chatIsArchived)
        return chatIsArchived
    }
}

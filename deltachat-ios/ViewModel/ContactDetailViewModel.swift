import UIKit

protocol ContactDetailViewModelProtocol {
    var contactId: Int { get }
    var contact: DcContact { get }
    var numberOfSections: Int { get }
    var chatIsArchived: Bool { get }
    func numberOfRowsInSection(_ : Int) -> Int
    func typeFor(section: Int) -> ContactDetailViewModel.ProfileSections
    func update(sharedChatCell: ContactCell, row index: Int)
    func getSharedChatIdAt(indexPath: IndexPath) -> Int
    func titleFor(section: Int) -> String?
}

class ContactDetailViewModel: ContactDetailViewModelProtocol {

    let context: DcContext
    enum ProfileSections {
        case startChat
        case sharedChats
        case chatActions //  archive chat, block chat, delete chats
    }

    var contactId: Int

    var contact: DcContact
    private let chatId: Int?
    private let sharedChats: DcChatlist
    private let startChatOption: Bool
    private var sections: [ProfileSections] = []

    /// if chatId is nil this is a contact detail with 'start chat'-option
    init(contactId: Int, chatId: Int?, context: DcContext) {
        self.context = context
        self.contactId = contactId
        self.chatId = chatId
        self.contact = DcContact(id: contactId)
        self.startChatOption = chatId == nil
        self.sharedChats = context.getChatlist(flags: 0, queryString: nil, queryId: contactId)

        if startChatOption {
            sections.append(.startChat)
        }
        if sharedChats.length > 0 {
            sections.append(.sharedChats)
        }
        sections.append(.chatActions)
    }

    func typeFor(section: Int) -> ContactDetailViewModel.ProfileSections {
        return sections[section]
    }

    var chatIsArchived: Bool {
        guard let chatId = chatId else {
            safe_fatalError("This is a ContactDetail view with no chat id")
            return false
        }
        return DcChat(id: chatId).isArchived
    }

    var numberOfSections: Int {
        return sections.count
    }

    func numberOfRowsInSection(_ section: Int) -> Int {
        switch sections[section] {
        case .sharedChats: return sharedChats.length
        case .startChat: return 1
        case .chatActions: return 3
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
        let cellViewModel = ChatCellViewModel(chatData: cellData)
        cell.updateCell(cellViewModel: cellViewModel)
    }

    func titleFor(section: Int) -> String? {
        if sections[section] == .sharedChats {
           return String.localized("profile_shared_chats")
        }
        return nil
      }
}

import UIKit

protocol ContactDetailViewModelProtocol {
    var contactId: Int { get }
    var contact: DcContact { get }
    var numberOfSections: Int { get }
    func numberOfRowsInSection(_ : Int) -> Int
    func typeFor(section: Int) -> ContactDetailViewModel.SectionType
    func update(actionCell: ActionCell, section: Int)
    func update(sharedChatCell: ContactCell, row index: Int)
    func getSharedChatIdAt(indexPath: IndexPath) -> Int
    func titleFor(section: Int) -> String?
}

class ContactDetailViewModel: ContactDetailViewModelProtocol {

    let context: DcContext
    enum SectionType {
        case contact
        case startChat
        case sharedChats
        case blockContact
    }

    var contactId: Int

    var contact: DcContact
    private let sharedChats: DcChatlist
    private let startChatOption: Bool

    private var sections: [SectionType] = []

    init(contactId: Int, startChatOption: Bool, context: DcContext) {
        self.context = context
        self.contactId = contactId
        self.contact = DcContact(id: contactId)
        self.startChatOption = startChatOption
        self.sharedChats = context.getChatlist(flags: 0, queryString: nil, queryId: contactId)

        if startChatOption {
            sections.append(.startChat)
        }
        if sharedChats.length > 0 {
            sections.append(.sharedChats)
        }
        sections.append(.blockContact)
    }

    func typeFor(section: Int) -> ContactDetailViewModel.SectionType {
        return sections[section]
    }

    var numberOfSections: Int {
        return sections.count
    }

    func numberOfRowsInSection(_ section: Int) -> Int {
        switch sections[section] {
        case .sharedChats: return sharedChats.length
        case .contact, .blockContact, .startChat: return 1
        }
    }

    func update(actionCell: ActionCell, section: Int) {
        let type = sections[section]
        switch type {
        case .startChat:
            update(startChatCell: actionCell)
        case .blockContact:
            update(blockContactCell: actionCell)
        case .sharedChats:
            break
        }

    }

    func getSharedChatIdAt(indexPath: IndexPath) -> Int {
        let index = indexPath.row
        assert(sections[indexPath.section] == .sharedChats)
        return sharedChats.getChatId(index: index)
    }

    private func update(startChatCell cell: ActionCell) {
        cell.actionColor = SystemColor.blue.uiColor
        cell.actionTitle = String.localized("menu_new_chat")
        cell.selectionStyle = .none
    }

    private func update(blockContactCell cell: ActionCell) {
        let cell = ActionCell()
        cell.actionTitle = contact.isBlocked ? String.localized("menu_unblock_contact") : String.localized("menu_block_contact")
        cell.actionColor = contact.isBlocked ? SystemColor.blue.uiColor : UIColor.red
        cell.selectionStyle = .none
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
            String.localized("menu_shared_chats")
        }
        return nil
      }
}

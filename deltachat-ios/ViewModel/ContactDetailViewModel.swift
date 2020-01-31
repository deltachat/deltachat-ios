import UIKit

protocol ContactDetailViewModelProtocol {
    var contactId: Int { get }
    var numberOfSections: Int { get }
    func numberOfRowsInSection(_ : Int) -> Int
    func update(cell: UITableViewCell, at indexPath: IndexPath)
    func getSharedChatIdAt(indexPath: IndexPath) -> Int
}

class ContactDetailViewModel: ContactDetailViewModelProtocol {

    private enum SectionType {
        case START_CHAT
        case SHARED_CHATS
        case BLOCK_CONTACT
    }

    var contactId: Int

    private lazy var contact: DcContact = {
        return DcContact(id: contactId)
    }()

    private let sharedChats: DcChatlist
    private let startChatOption: Bool

    private var sections: [SectionType] = []

    init(contactId: Int, startChatOption: Bool, context: DcContext) {
        self.contactId = contactId
        self.startChatOption = startChatOption
        self.sharedChats = context.getChatlist(flags: 0, queryString: nil, queryId: contactId)

        if startChatOption {
            sections.append(.START_CHAT)
        }
        if sharedChats.length > 0 {
            sections.append(.SHARED_CHATS)
        }
        sections.append(.BLOCK_CONTACT)

    }

    var numberOfSections: Int {

        return sections.count
    }

    func numberOfRowsInSection(_ section:  Int) -> Int {
        switch sections[section] {
        case .SHARED_CHATS: return sharedChats.length
        case .BLOCK_CONTACT, .START_CHAT: return 1
        }
    }

    func update(cell: UITableViewCell, at indexPath: IndexPath) {
        let type = sections[indexPath.section]
        switch type {
        case .START_CHAT:
            if let actionCell = cell as? ActionCell {
                update(startChatCell: actionCell)
            }
        case .BLOCK_CONTACT:
            if let actionCell = cell as? ActionCell {
                update(blockContactCell: actionCell)
            }
        case .SHARED_CHATS:
            if let contactCell = cell as? ContactCell {
                update(sharedChatCell: contactCell, row: indexPath.row)
            }
        }
    }

    func getSharedChatIdAt(indexPath: IndexPath) -> Int {
        let index = indexPath.row
        assert(sections[indexPath.section] == .SHARED_CHATS)
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

    private func update(sharedChatCell cell: ContactCell, row: Int) {
        
    }

}

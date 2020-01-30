import Foundation

protocol ContactDetailViewModelProtocol {
    var contactId: Int { get }
    var numberOfSections: Int { get }
    func numberOfRowsInSection(_ : Int) -> Int
    func updateCellAt(indexPath: IndexPath)
    func getSharedChatIdAt(indexPath: IndexPath) -> Int
}

class ContactDetailViewModel: ContactDetailViewModelProtocol {

    private enum SectionType {
        case START_CHAT
        case SHARED_CHATS
        case BLOCK_CONTACT
    }

    var contactId: Int

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

    func updateCellAt(indexPath: IndexPath) {
        return
    }

    func getSharedChatIdAt(indexPath: IndexPath) -> Int {
        let index = indexPath.row
        assert(sections[indexPath.section] == .SHARED_CHATS)
        return sharedChats.getChatId(index: index)
    }


}

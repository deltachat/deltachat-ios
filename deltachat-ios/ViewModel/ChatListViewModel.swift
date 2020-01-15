import UIKit

protocol AvatarTextCellViewModel {
    var type: CellType { get }
    var metaData: CellMetaData { get }
    var title: String { get }
    var subtitle: String { get }
    var avartarTitle: String { get }
    var avatarColor: String { get }
    // add highlighting search results
}

enum CellType: CellMetaData {
    case CONTACT
    case CHAT
}

struct ContactCellMetaData: CellMetaData {
    let contactId: Int
}

struct ChatCellMetaData: CellMetaData {
    let chatId: Int
    let summary: DcLot
    let unreadMessages: Int
}


protocol CellMetaData {
    // empty
}


protocol ChatListViewModelProtocol: class, UISearchResultsUpdating {
    var numberOfSections: Int { get }

    var onChatListUpdate: VoidFunction? { get set }
    var showArchive: Bool { get }
    var archivedChatsCount: Int { get }
    func numberOfRowsIn(section: Int) -> Int
    func msgIdFor(indexPath: IndexPath) -> Int?
    func chatIdFor(indexPath: IndexPath) -> Int? // to differentiate betweeen deaddrop / archive / default
    func titleForHeaderIn(section: Int) -> String?
    func chatCellViewModel(indexPath: IndexPath) -> ChatListCellViewModel
    func beginFiltering()
    func endFiltering()

    func archieveChat(chatId: Int)
    func deleteChat(chatId: Int)
}

class ChatListCellViewModel {
    let chatId: Int?
    let msgId: Int?
    let summary: DcLot?
    let unreadMessages: Int?
    let searchHighlights: [ContactHighlights]
    let msgIdSearchResult: [Int]

    init(chatId: Int?, msgId: Int?, summary: DcLot?, unreadMessages: Int?, searchHighlights: [ContactHighlights] = [], msgIdSearchResult: [Int] = []) {
        self.chatId = chatId
        self.msgId = msgId
        self.summary = summary
        self.unreadMessages = unreadMessages
        self.searchHighlights = searchHighlights
        self.msgIdSearchResult = msgIdSearchResult
    }
}

class ChatListViewModel: NSObject, ChatListViewModelProtocol {
    func titleForHeaderIn(section: Int) -> String? {
        if searchActive {
            return searchResultSections[section].type.rawValue
        }
        return nil
    }


    var onChatListUpdate: VoidFunction? // callback that will reload chatListTable

    enum ChatListSectionType: String {
        case chats = "Chats"
        case contacts = "Contacts"
        case messages = "Messages"
    }

    class ChatListSection {
        let type: ChatListSectionType
        var cellData: [ChatListCellViewModel] = []
        init(type: ChatListSectionType) {
            self.type = type
        }
    }

    var archivedChatsCount: Int {
        let chatList = dcContext.getChatlist(flags: DC_GCL_ARCHIVED_ONLY, queryString: nil, queryId: 0)
        return chatList.length
    }

    private var chatsCount: Int {
        if showArchive {
            return archivedChatsCount
        }
        return cellViewModels.count
    }

    // for search filtering
    var filteredChats: ChatListSection = ChatListSection(type: .chats)
    var filteredContacts: ChatListSection = ChatListSection(type: .contacts)
    var filteredMessages: ChatListSection = ChatListSection(type: .messages)

    private var searchResultSections: [ChatListSection] {
        return [filteredChats, filteredContacts, filteredMessages]
            .filter { !$0.cellData.isEmpty } //
    }

    private var cellViewModels: [ChatListCellViewModel] = []

    func chatCellViewModel(indexPath: IndexPath) -> ChatListCellViewModel {
        if searchActive {
            return searchResultSections[indexPath.section].cellData[indexPath.row]
        } else {
            return cellViewModels[indexPath.row]
        }
    }

    private var chatList: DcChatlist {
        var gclFlags: Int32 = 0
        if showArchive {
            gclFlags |= DC_GCL_ARCHIVED_ONLY
        }
        return dcContext.getChatlist(flags: gclFlags, queryString: nil, queryId: 0)
    }

    private var dcContext: DcContext
    let showArchive: Bool

    var searchActive: Bool = false

    init(dcContext: DcContext, showArchive: Bool) {
        self.dcContext = dcContext
        self.showArchive = showArchive
        dcContext.updateDeviceChats()
        super.init()
        cellViewModels = makeUnfilteredCellViewModels()
    }

    var numberOfSections: Int {
        if searchActive {
            return searchResultSections.count
        }
        return 1
    }

    func numberOfRowsIn(section: Int) -> Int {
        if searchActive {
            return searchResultSections[section].cellData.count
        }
        return chatsCount
    }

    private func makeUnfilteredCellViewModels() -> [ChatListCellViewModel] {
        var viewModels: [ChatListCellViewModel] = []
        let _ = (0..<chatList.length).map {
            let chatId = chatList.getChatId(index: $0)
            let msgId = chatList.getMsgId(index: $0)
            let summary = chatList.getSummary(index: $0)
            let unreadMessages = dcContext.getUnreadMessages(chatId: chatId)
            viewModels.append(ChatListCellViewModel(chatId: chatId, msgId: msgId, summary: summary, unreadMessages: unreadMessages))
        }
        return viewModels
    }

    func chatIdFor(indexPath: IndexPath) -> Int? {
        return chatCellViewModel(indexPath: indexPath).chatId
    }

    func msgIdFor(indexPath: IndexPath) -> Int? {
        return chatCellViewModel(indexPath: indexPath).msgId
    }

    /*
    func chatSummaryFor(indexPath: IndexPath) -> DcLot {
        if searchActive {
            return filteredSearchResults[indexPath.row].entity.
        }
        return chatList.getSummary(index: indexPath.row)
    }
    */

    func deleteChat(chatId: Int) {
        dcContext.deleteChat(chatId: chatId)
        onChatListUpdate?()
    }

    func archieveChat(chatId: Int) {
        dcContext.archiveChat(chatId: chatId, archive: !self.showArchive)
        onChatListUpdate?()
    }

    func getUnreadMessages(chatId: Int) -> Int {
        let msg = dcContext.getUnreadMessages(chatId: chatId)
        return msg
    }

    func beginFiltering() {
        searchActive = true
    }

    func endFiltering() {
        searchActive = false
    }
}

// MARK: UISearchResultUpdating
extension ChatListViewModel: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text {
            filterContentForSearchText(searchText)
        }
    }

    private func filterContentForSearchText(_ searchText: String, scope _: String = String.localized("pref_show_emails_all")) {

        if !searchText.isEmpty {
            filterAndUpdateList(searchText: searchText)
            /*
            var filteredCellViewModels: [ChatListCellViewModel] = []

            let msgIds = dcContext.searchMessages(searchText: searchText)

            var filteredChatIds: Set<Int> = []
            var msgIdsInChat: [Int: [Int]] = [:]

            let _ = msgIds.map {
                let chatId = DcMsg(id: $0).chatId
                filteredChatIds.insert(chatId)
                if msgIdsInChat[chatId] != nil {
                    msgIdsInChat[chatId]!.append($0)
                } else {
                    msgIdsInChat[chatId] = [$0]
                }
            }

            // filter through chatList
            let _ = (0..<chatList.length).map {
                let chatId = chatList.getChatId(index: $0)
                if filteredChatIds.contains(chatId) {
                    let chatId = chatList.getChatId(index: $0)
                    let msgId = chatList.getMsgId(index: $0)
                    let summary = chatList.getSummary(index: $0)
                    let unreadMessages = dcContext.getUnreadMessages(chatId: chatId)

                    assert(msgIdsInChat[chatId] != nil)

                    let cellViewModel = ChatListCellViewModel(
                        chatId: chatId,
                        msgId: msgId,
                        summary: summary,
                        unreadMessages: unreadMessages,
                        searchHighlights: [],
                        msgIdSearchResult: msgIdsInChat[chatId] ?? []
                    )
                    filteredCellViewModels.append(cellViewModel)
                }

            }
            self.cellViewModels = filteredCellViewModels
            */
        } else {
            resetSearch()
        }
        onChatListUpdate?()
    }

    private func filterAndUpdateList(searchText: String) {

        // #1 chats with searchPattern in title bar
        var filteredChatCellViewModels: [ChatListCellViewModel] = []
        _ = (0..<chatList.length).map {
            let chatId = chatList.getChatId(index: $0)
            let chat = DcChat(id: chatId)
            let chatName = chat.name
            let summary = chatList.getSummary(index: $0)
            let unreadMessages = getUnreadMessages(chatId: chatId)

            let indexes = chatName.contains(subSequence: searchText)
            let titleHighLight = ContactHighlights(contactDetail: .NAME, indexes: indexes)
            if !indexes.isEmpty {
                let viewModel = ChatListCellViewModel(
                    chatId: chatId,
                    msgId: nil,
                    summary: summary,
                    unreadMessages: unreadMessages,
                    searchHighlights: [titleHighLight],
                    msgIdSearchResult: []
                )
                filteredChatCellViewModels.append(viewModel)
            }
        }

        filteredChats.cellData = filteredChatCellViewModels

        // #2 contacts with searchPattern in name
        var filteredContactCellViewModels: [ChatListCellViewModel] = []
        let contactIds: [Int] = dcContext.getContacts(flags: DC_GCL_ADD_SELF)

        // contactWithSearchResults.indexesToHightLight empty by default
        var contacts: [ContactWithSearchResults] {
            return contactIds.map { ContactWithSearchResults(contact: DcContact(id: $0), indexesToHighlight: []) }
        }

        let contactsWithHighlights: [ContactWithSearchResults] = contacts.map { contact in
            let indexes = contact.contact.containsExact(searchText: searchText)
            return ContactWithSearchResults(contact: contact.contact, indexesToHighlight: indexes)
        }

        let contactResults = contactsWithHighlights.filter { !$0.indexesToHighlight.isEmpty }

        for contact in contactResults {
            let viewModel = ChatListCellViewModel(
                chatId: nil,
                msgId: nil,
                summary: nil,
                unreadMessages: nil,
                searchHighlights: contact.indexesToHighlight,
                msgIdSearchResult: []
            )
            filteredContactCellViewModels.append(viewModel)
        }
        filteredContacts.cellData = filteredContactCellViewModels

        // #3 messages with searchPattern
        let msgIds = dcContext.searchMessages(searchText: searchText)
        var filteredMessageCellViewModels: [ChatListCellViewModel] = []

        for msgId in msgIds {
            let msg: DcMsg = DcMsg(id: msgId)
            let chatId: Int = msg.chatId
            let chat: DcChat = DcChat(id: chatId)
            let summary: DcLot = msg.summary(chat: chat)
            let unreadMessages = getUnreadMessages(chatId: chatId)
            let viewModel = ChatListCellViewModel(chatId: chatId, msgId: msgId, summary: summary, unreadMessages: unreadMessages, searchHighlights: [], msgIdSearchResult: [])
            filteredMessageCellViewModels.append(viewModel)
        }
        filteredMessages.cellData = filteredMessageCellViewModels
    }

    private func resetSearch() {
        filteredChats.cellData = makeUnfilteredCellViewModels()
        filteredContacts.cellData = []
        filteredMessages.cellData = []
    }
}

import UIKit

protocol ChatListViewModelProtocol: class, UISearchResultsUpdating {

    var onChatListUpdate: VoidFunction? { get set }

    var isArchive: Bool { get }

    var numberOfSections: Int { get }
    func numberOfRowsIn(section: Int) -> Int
    func cellDataFor(section: Int, row: Int) -> AvatarCellViewModel

    func msgIdFor(row: Int) -> Int?
    func chatIdFor(section: Int, row: Int) -> Int? // needed to differentiate betweeen deaddrop / archive / default

    // search related
    var searchActive: Bool { get }
    func beginSearch()
    func endSearch()
    func titleForHeaderIn(section: Int) -> String? // only visible on search results

    /// returns ROW of table
    func deleteChat(chatId: Int) -> Int
    func archiveChatToggle(chatId: Int)
    func pinChatToggle(chatId: Int)
    func refreshData()

    var numberOfArchivedChats: Int { get }
}

class ChatListViewModel: NSObject, ChatListViewModelProtocol {

    var onChatListUpdate: VoidFunction?

    enum ChatListSectionType {
        case chats
        case contacts
        case messages
    }

    class ChatListSection {
        let type: ChatListSectionType
        var headerTitle: String {
            switch type {
            case .chats:
                return String.localized("pref_chats")
            case .contacts:
                return String.localized("contacts_headline")
            case .messages:
                return String.localized("pref_messages")
            }
        }
        var cellData: [AvatarCellViewModel] = []
        init(type: ChatListSectionType) {
            self.type = type
        }
    }

    var isArchive: Bool
    private let dcContext: DcContext

    var searchActive: Bool = false
    private var searchTextEmpty: Bool = true

    // if searchfield is empty we show default chat list
    private var showSearchResults: Bool {
        return searchActive && !searchTextEmpty
    }

    private var chatList: DcChatlist!

    // for search filtering
    private var searchResultsChats: ChatListSection = ChatListSection(type: .chats)
    private var searchResultsContacts: ChatListSection = ChatListSection(type: .contacts)
    private var searchResultsMessages: ChatListSection = ChatListSection(type: .messages)

    private var searchResultSections: [ChatListSection] {
        return [searchResultsChats, searchResultsContacts, searchResultsMessages]
            .filter { !$0.cellData.isEmpty }
    }

    init(dcContext: DcContext, isArchive: Bool) {
        dcContext.updateDeviceChats()
        self.isArchive = isArchive
        self.dcContext = dcContext
        super.init()
        updateChatList(notifyListener: true)
    }

    private func updateChatList(notifyListener: Bool) {
        var gclFlags: Int32 = 0
        if isArchive {
            gclFlags |= DC_GCL_ARCHIVED_ONLY
        }
        self.chatList = dcContext.getChatlist(flags: gclFlags, queryString: nil, queryId: 0)
        if notifyListener {
            onChatListUpdate?()
        }
    }

    var numberOfSections: Int {
        if showSearchResults {
            return searchResultSections.count
        }
        return 1
    }

    func numberOfRowsIn(section: Int) -> Int {
        if showSearchResults {
            return searchResultSections[section].cellData.count
        }
        return chatList.length
    }

    func cellDataFor(section: Int, row: Int) -> AvatarCellViewModel {
        if showSearchResults {
            return searchResultSections[section].cellData[row]
        }

        let chatId = chatList.getChatId(index: row)
        let summary = chatList.getSummary(index: row)
        let unreadMessages = dcContext.getUnreadMessages(chatId: chatId)
        let viewModel = ChatCellViewModel(
            chatData: ChatCellData(
                chatId: chatId,
                summary: summary,
                unreadMessages: unreadMessages
            )
        )
        return viewModel
    }

    func titleForHeaderIn(section: Int) -> String? {
        if showSearchResults {
            return searchResultSections[section].headerTitle
        }
        return nil
    }

    func chatIdFor(section: Int, row: Int) -> Int? {
        let cellData = cellDataFor(section: section, row: row)
        switch cellData.type {
        case .CHAT(let data):
            return data.chatId
        case .CONTACT:
            return nil
        }
    }

    func msgIdFor(row: Int) -> Int? {
        if searchActive {
            return nil
        }
        return chatList.getMsgId(index: row)
    }

    func refreshData() {
        updateChatList(notifyListener: true)
    }

    func beginSearch() {
        searchActive = true
    }

    func endSearch() {
        searchTextEmpty = true
        searchActive = false
    }

    func deleteChat(chatId: Int) -> Int {
        // find index of chatId
        let indexToDelete = Array(0..<chatList.length).filter { chatList.getChatId(index: $0) == chatId }.first
        dcContext.deleteChat(chatId: chatId)
        updateChatList(notifyListener: false)
        safe_assert(indexToDelete != nil)
        return indexToDelete ?? -1
    }

    func archiveChatToggle(chatId: Int) {
        dcContext.archiveChat(chatId: chatId, archive: !self.isArchive)
        updateChatList(notifyListener: false)
    }

    func pinChatToggle(chatId: Int) {
        let chat = DcChat(id: chatId)
        let pinned = chat.visibility==DC_CHAT_VISIBILITY_PINNED
        self.dcContext.setChatVisibility(chatId: chatId, visibility: pinned ? DC_CHAT_VISIBILITY_NORMAL : DC_CHAT_VISIBILITY_PINNED)
        updateChatList(notifyListener: false)
    }

    var numberOfArchivedChats: Int {
        let chatList = dcContext.getChatlist(flags: DC_GCL_ARCHIVED_ONLY, queryString: nil, queryId: 0)
        return chatList.length
    }
}

// MARK: UISearchResultUpdating
extension ChatListViewModel: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text {
            self.searchTextEmpty = searchText.isEmpty
            filterContentForSearchText(searchText)
            return
        }
        searchTextEmpty = true
    }

    private func filterContentForSearchText(_ searchText: String) {
        if !searchText.isEmpty {
            filterAndUpdateList(searchText: searchText)
        } else {
            // when search input field empty we show default chatList
            resetSearch()
        }
        onChatListUpdate?()
    }

    private func filterAndUpdateList(searchText: String) {

        // #1 chats with searchPattern in title bar
        var filteredChatCellViewModels: [ChatCellViewModel] = []
        var flags: Int32 = 0
        flags |= DC_GCL_NO_SPECIALS
        let filteredChatList = dcContext.getChatlist(flags: flags, queryString: searchText, queryId: 0)
        _ = (0..<filteredChatList.length).map {
            let chatId = chatList.getChatId(index: $0)
            let chat = DcChat(id: chatId)
            let chatName = chat.name
            let summary = chatList.getSummary(index: $0)
            let unreadMessages = dcContext.getUnreadMessages(chatId: chatId)
            let chatTitleIndexes = chatName.containsExact(subSequence: searchText)

            let viewModel = ChatCellViewModel(
                chatData: ChatCellData(
                    chatId: chatId,
                    summary: summary,
                    unreadMessages: unreadMessages
                ),
                titleHighlightIndexes: chatTitleIndexes
            )
            filteredChatCellViewModels.append(viewModel)
        }
        searchResultsChats.cellData = filteredChatCellViewModels

        // #2 contacts with searchPattern in name or in email
        var filteredContactCellViewModels: [ContactCellViewModel] = []
        let contactIds: [Int] = dcContext.getContacts(flags: DC_GCL_ADD_SELF, queryString: searchText)

        let contacts = contactIds.map { return DcContact(id: $0) }

        for contact in contacts {
            let nameIndexes = contact.displayName.containsExact(subSequence: searchText)
            let emailIndexes = contact.email.containsExact(subSequence: searchText)

            // contact contains searchText
            let viewModel = ContactCellViewModel(
                contactData: ContactCellData(
                    contactId: contact.id
                ),
                titleHighlightIndexes: nameIndexes,
                subtitleHighlightIndexes: emailIndexes
            )
            filteredContactCellViewModels.append(viewModel)
        }
        searchResultsContacts.cellData = filteredContactCellViewModels

        // #3 messages with searchPattern (filtered by dc_core)
        let msgIds = dcContext.searchMessages(searchText: searchText)
        var filteredMessageCellViewModels: [ChatCellViewModel] = []


        for msgId in msgIds {
            let msg: DcMsg = DcMsg(id: msgId)
            let chatId: Int = msg.chatId
            let chat: DcChat = DcChat(id: chatId)
            let summary: DcLot = msg.summary(chat: chat)
            let unreadMessages = dcContext.getUnreadMessages(chatId: chatId)

            let viewModel = ChatCellViewModel(
                chatData: ChatCellData(
                    chatId: chatId,
                    summary: summary,
                    unreadMessages: unreadMessages
                )
            )
            let subtitle = viewModel.subtitle
            viewModel.subtitleHighlightIndexes = subtitle.containsExact(subSequence: searchText)

            filteredMessageCellViewModels.append(viewModel)
        }
        searchResultsMessages.cellData = filteredMessageCellViewModels
    }

    private func resetSearch() {
        searchResultsChats.cellData = []
        searchResultsContacts.cellData = []
        searchResultsMessages.cellData = []
    }
}

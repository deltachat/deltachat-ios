import UIKit
import DcCore


// MARK: - ChatListViewModel
class ChatListViewModel: NSObject {

    var onChatListUpdate: VoidFunction?

    enum ChatListSectionType {
        case chats
        case contacts
    }

    private let dcContext: DcContext

    var searchActive: Bool = false

    // if searchfield is empty we show default chat list
    private var showSearchResults: Bool {
        return searchActive && !searchText.isEmpty
    }

    private var chatList: DcChatlist!

    // for search filtering
    private var searchText: String = ""
    private var searchResultChatList: DcChatlist?
    private var searchResultContactIds: [Int] = []

    // to manage sections dynamically
    private var searchResultsChatsSection: ChatListSectionType = .chats
    private var searchResultsContactsSection: ChatListSectionType = .contacts
    private var searchResultSections: [ChatListSectionType] = []

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init()
        updateChatList(notifyListener: true)
    }

    private func updateChatList(notifyListener: Bool) {
        self.chatList = dcContext.getChatlist(flags: DC_GCL_ADD_ALLDONE_HINT | DC_GCL_FOR_FORWARDING | DC_GCL_NO_SPECIALS, queryString: nil, queryId: 0)
        if notifyListener {
            onChatListUpdate?()
        }
    }

    func getChatId(section: Int, row: Int) -> Int? {
        if showSearchResults {
            switch searchResultSections[section] {
            case .chats:
                let list: DcChatlist? = searchResultChatList
                return list?.getChatId(index: row)
            case .contacts:
                return searchResultContactIds[row]
            }
        }
        return chatList.getChatId(index: row)
    }

    func cellDataFor(section: Int, row: Int) -> AvatarCellViewModel {
        if showSearchResults {
            switch searchResultSections[section] {
            case .chats:
                return makeChatCellViewModel(index: row, searchText: searchText)
            case .contacts:
                return ContactCellViewModel.make(contactId: searchResultContactIds[row], searchText: searchText, dcContext: dcContext)
            }
        }
        return makeChatCellViewModel(index: row, searchText: "")
    }

    func makeChatCellViewModel(index: Int, searchText: String) -> AvatarCellViewModel {
        let list: DcChatlist = searchResultChatList ?? chatList
        let chatId = list.getChatId(index: index)
        let summary = list.getSummary(index: index)

        let chat = dcContext.getChat(chatId: chatId)
        let unreadMessages = dcContext.getUnreadMessages(chatId: chatId)

        var chatTitleIndexes: [Int] = []
        if !searchText.isEmpty {
            let chatName = chat.name
            chatTitleIndexes = chatName.containsExact(subSequence: searchText)
        }

        let viewModel = ChatCellViewModel(
            dcContext: dcContext,
            chatData: ChatCellData(
                chatId: chatId,
                highlightMsgId: nil,
                summary: summary,
                unreadMessages: unreadMessages
            ),
            titleHighlightIndexes: chatTitleIndexes
        )
        return viewModel
    }


    var numberOfSections: Int {
        if showSearchResults {
            return searchResultSections.count
        }
        return 1
    }

    func numberOfRowsIn(section: Int) -> Int {
        if showSearchResults {
            switch searchResultSections[section] {
            case .chats:
                return searchResultChatList?.length ?? 0
            case .contacts:
                return searchResultContactIds.count
            }
        }
        return chatList.length
    }

    func titleForHeaderIn(section: Int) -> String? {
        if showSearchResults {
            let title: String
            switch searchResultSections[section] {
            case .chats:
                title = "n_chats"
            case .contacts:
                title = "n_contacts"
            }
            return String.localized(stringID: title, parameter: numberOfRowsIn(section: section))
        }
        return nil
    }

    func refreshData() {
        updateChatList(notifyListener: true)
    }

    func beginSearch() {
        searchActive = true
    }

    func endSearch() {
        searchActive = false
        searchText = ""
        resetSearch()
    }

    var emptySearchText: String? {
        if searchActive && numberOfSections == 0 {
            return searchText
        }
        return nil
    }

    // MARK: - search
    func updateSearchResultSections() {
        var sections: [ChatListSectionType] = []
        if let chatList = searchResultChatList, chatList.length > 0 {
            sections.append(searchResultsChatsSection)
        }
        if !searchResultContactIds.isEmpty {
            sections.append(searchResultsContactsSection)
        }
        searchResultSections = sections
    }

    func resetSearch() {
        searchResultChatList = nil
        searchResultContactIds = []
        updateSearchResultSections()
    }

    func filterContentForSearchText(_ searchText: String) {
        if !searchText.isEmpty {
            filterAndUpdateList(searchText: searchText)
        } else {
            // when search input field empty we show default chatList
            resetSearch()
        }
        onChatListUpdate?()
    }

    func filterAndUpdateList(searchText: String) {

        // #1 - search for chats with searchPattern in title
        let flags = DC_GCL_ADD_ALLDONE_HINT | DC_GCL_FOR_FORWARDING | DC_GCL_NO_SPECIALS
        searchResultChatList = dcContext.getChatlist(flags: flags, queryString: searchText, queryId: 0)

        // #2 - search for contacts with searchPattern in name or in email
        searchResultContactIds = dcContext.getContacts(flags: DC_GCL_ADD_SELF, queryString: searchText)

        updateSearchResultSections()
    }
}

// MARK: UISearchResultUpdating
extension ChatListViewModel: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        self.searchText = searchController.searchBar.text ?? ""
        if let searchText = searchController.searchBar.text {
            filterContentForSearchText(searchText)
            return
        }
    }
}

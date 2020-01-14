import UIKit

typealias VoidFunction = () -> Void

protocol ChatListViewModelProtocol: class, UISearchResultsUpdating {
    var chatsCount: Int { get }
    var showArchive: Bool { get }
    var onChatListUpdate: VoidFunction? { get set }
    var archivedChatsCount: Int { get }
    func chatIdFor(indexPath: IndexPath) -> Int?
    func msgIdFor(indexPath: IndexPath) -> Int?
    func chatSummaryFor(indexPath: IndexPath) -> DcLot
    func chatDetailFor(indexPath: IndexPath) -> ChatListCellViewModelProtocol
    func deleteChat(chatId: Int)
    func archieveChat(chatId: Int)
    func getUnreadMessages(chatId: Int) -> Int
    func beginFiltering()
    func endFiltering()
}

protocol ChatListCellViewModelProtocol {

}

class ChatListCellViewModel: ChatListCellViewModelProtocol {

}

class ChatListViewModel: NSObject, ChatListViewModelProtocol {

    var onChatListUpdate: VoidFunction? // callback that will reload chatListTable

    var archivedChatsCount: Int {
        let chatList = dcContext.getChatlist(flags: DC_GCL_ARCHIVED_ONLY, queryString: nil, queryId: 0)
        return chatList.length
    }

    var chatsCount: Int {
        if showArchive {
            return archivedChatsCount
        }
        if searchActive {
            return filteredSearchResults.count
        }
        return chatList.length
    }

    private var chatList: DcChatlist {
        var gclFlags: Int32 = 0
        if showArchive {
            gclFlags |= DC_GCL_ARCHIVED_ONLY
        }
        return dcContext.getChatlist(flags: gclFlags, queryString: nil, queryId: 0)
    }

    private var unfilteredSearchResults: [SearchResult<DcChat>] = []
    private var filteredSearchResults: [SearchResult<DcChat>] = []
    // private var searchResults: [SearchResult<DcChat>] = []

    private var dcContext: DcContext
    let showArchive: Bool

    var searchActive: Bool = false

    init(dcContext: DcContext, showArchive: Bool) {
        self.dcContext = dcContext
        self.showArchive = showArchive
        dcContext.updateDeviceChats()
    }

    func chatDetailFor(indexPath: IndexPath) -> ChatListCellViewModelProtocol {
        return ChatListCellViewModel()
    }

    func chatSummaryFor(indexPath: IndexPath) -> DcLot {

        return chatList.getSummary(index: indexPath.row)
    }

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
        let chatList = self.chatList
        // do this once
        self.unfilteredSearchResults = (0..<chatsCount).map {
            let id = chatList.getChatId(index: $0)
            return SearchResult<DcChat>(entity: DcChat(id: id), indexesToHighlight: [])
        }
    }

    func endFiltering() {
        searchActive = false
    }

    func msgIdFor(indexPath: IndexPath) -> Int? {
        return chatList.getMsgId(index: indexPath.row)
    }

    func chatIdFor(indexPath: IndexPath) -> Int? {
        return chatList.getChatId(index: indexPath.row)
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
            let msgIds = dcContext.searchMessages(searchText: searchText)
            let chatIds = msgIds.map { return DcMsg(id: $0).chatId }

            filteredSearchResults = chatIds.map {
                return SearchResult<DcChat>(entity: DcChat(id: $0), indexesToHighlight: [])
            }
        } else {
            // if no
            filteredSearchResults = (0..<chatList.length).map {
                return SearchResult<DcChat>(entity: DcChat(id: chatList.getChatId(index: $0)), indexesToHighlight: [])
            }
        }
        onChatListUpdate?()
    }
}

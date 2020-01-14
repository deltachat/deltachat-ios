import UIKit

typealias VoidFunction = () -> Void

protocol ChatListViewModelProtocol: class, UISearchResultsUpdating {
    var onChatListUpdate: VoidFunction? { get set }
    var showArchive: Bool { get }
    var chatsCount: Int { get }
    func chatIdFor(indexPath: IndexPath) -> Int? // to differentiate betweeen deaddrop / archive / default

    var archivedChatsCount: Int { get }
    func msgIdFor(indexPath: IndexPath) -> Int?
    func chatCellViewModel(indexPath: IndexPath) -> ChatListCellViewModel
//    func chatSummaryFor(indexPath: IndexPath) -> DcLot
//    func chatDetailFor(indexPath: IndexPath) -> ChatListCellViewModelProtocol
//    func getUnreadMessages(chatId: Int) -> Int
    func beginFiltering()
    func endFiltering()


    func archieveChat(chatId: Int)
    func deleteChat(chatId: Int)
}

class ChatListCellViewModel {
    let chatId: Int
    let msgId: Int
    let summary: DcLot
    let unreadMessages: [Int]
    let indexesToHighlight: [Int]
    let msgIdSearchResult: [Int]

    init(chatId: Int, msgId: Int, summary: DcLot, unreadMessages: [Int], indexesToHighlight: [Int] = [], msgIdSearchResult: [Int] = []) {
        self.chatId = chatId
        
        self.msgId = msgId
        self.summary = summary
        self.unreadMessages = unreadMessages
        self.indexesToHighlight = indexesToHighlight
        self.msgIdSearchResult = msgIdSearchResult
    }
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
        return cellViewModels.count
    }

    private let cellViewModelsComplete: [ChatListCellViewModel]
    private var cellViewModels: [ChatListCellViewModel]

    func chatCellViewModel(indexPath: IndexPath) -> ChatListCellViewModel {
        return cellViewModels[indexPath.row]
    }

    private var chatList: DcChatlist {
        var gclFlags: Int32 = 0
        if showArchive {
            gclFlags |= DC_GCL_ARCHIVED_ONLY
        }
        return dcContext.getChatlist(flags: gclFlags, queryString: nil, queryId: 0)
    }

   //  private var unfilteredSearchResults: [SearchResult<DcChat>] = []
   // private var filteredSearchResults: [SearchResult<DcChat>] = []
    // private var searchResults: [SearchResult<DcChat>] = []

    private var dcContext: DcContext
    let showArchive: Bool

    var searchActive: Bool = false

    init(dcContext: DcContext, showArchive: Bool) {
        self.dcContext = dcContext
        self.showArchive = showArchive
        dcContext.updateDeviceChats()
        self.cellViewModelsComplete = (0..<chatList.length).map {
            let chatId = chatList.getChatId(index: $0)
            let msgId = chatList.getMsgId(index: $0)
        }
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

protocol Searchable {
    func contains(searchText text: String) -> [ResultIndexes]
    func containsExact(searchText text: String) -> [ResultIndexes]
}

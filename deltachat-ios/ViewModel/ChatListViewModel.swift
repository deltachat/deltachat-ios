import UIKit
import DcCore
import Intents


// MARK: - ChatListViewModel
class ChatListViewModel: NSObject {

    var onChatListUpdate: VoidFunction?

    private var inBgSearch = false
    private var needsAnotherBgSearch = false

    enum ChatListSectionType {
        case chats
        case contacts
        case messages
    }

    private(set) public var isArchive: Bool
    private let dcContext: DcContext

    private(set) public var searchActive: Bool = false

    // if searchfield is empty we show default chat list
    private var showSearchResults: Bool {
        return searchActive && !searchText.isEmpty
    }

    var chatList: DcChatlist!

    // for search filtering
    private var searchText: String = ""
    private var searchResultChatList: DcChatlist?
    private var searchResultContactIds: [Int] = []
    private var searchResultMessageIds: [Int] = []

    // to manage sections dynamically
    private var searchResultsChatsSection: ChatListSectionType = .chats
    private var searchResultsContactsSection: ChatListSectionType = .contacts
    private var searchResultsMessagesSection: ChatListSectionType = .messages
    private var searchResultSections: [ChatListSectionType] = []

    private var isChatListUpdatePending = false
    private(set) var isEditing = false

    init(dcContext: DcContext, isArchive: Bool) {
        self.isArchive = isArchive
        self.dcContext = dcContext
        super.init()
        updateChatList(notifyListener: true)
    }

    private func updateChatList(notifyListener: Bool) {
        var gclFlags: Int32 = 0
        if isArchive {
            gclFlags |= DC_GCL_ARCHIVED_ONLY
        } else if RelayHelper.shared.isForwarding() || RelayHelper.shared.isSharing() {
            gclFlags |= DC_GCL_FOR_FORWARDING
        }
        self.chatList = dcContext.getChatlist(flags: gclFlags, queryString: nil, queryId: 0)
        if notifyListener {
            handleOnChatListUpdate()
        }
    }

    func handleOnChatListUpdate() {
        if isEditing {
            isChatListUpdatePending = true
            return
        }
        isChatListUpdatePending = false
        if let onChatListUpdate = onChatListUpdate {
            if Thread.isMainThread {
                onChatListUpdate()
            } else {
                DispatchQueue.main.async {
                    onChatListUpdate()
                }
            }
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
            switch searchResultSections[section] {
            case .chats:
                return searchResultChatList?.length ?? 0
            case .contacts:
                return searchResultContactIds.count
            case .messages:
                return searchResultMessageIds.count
            }
        }
        return chatList.length
    }

    func cellDataFor(section: Int, row: Int) -> AvatarCellViewModel {
        if showSearchResults && !searchResultSections.isEmpty {
            switch searchResultSections[section] {
            case .chats:
                return makeChatCellViewModel(index: row, searchText: searchText)

            case .contacts:
                if row >= 0 && row < searchResultContactIds.count {
                    return ContactCellViewModel.make(contactId: searchResultContactIds[row], searchText: searchText, dcContext: dcContext)
                } else {
                    logger.warning("search: requested contact index \(row) not in range 0..\(searchResultContactIds.count)")
                }

            case .messages:
                if row >= 0 && row < searchResultMessageIds.count {
                    return makeMessageCellViewModel(msgId: searchResultMessageIds[row])
                } else {
                    logger.warning("search: requested message index \(row) not in range 0..\(searchResultMessageIds.count)")
                }
            }
        }
        return makeChatCellViewModel(index: row, searchText: "")
    }

    // only visible on search results
    func titleForHeaderIn(section: Int) -> String? {
        if showSearchResults && !searchResultSections.isEmpty {
            switch searchResultSections[section] {
            case .chats:
                return String.localized(stringID: "n_chats", parameter: numberOfRowsIn(section: section))
            case .contacts:
                return String.localized(stringID: "n_contacts", parameter: numberOfRowsIn(section: section))
            case .messages:
                let count = numberOfRowsIn(section: section)
                var ret = String.localized(stringID: "n_messages", parameter: count)
                if count==1000 {
                    // a count of 1000 results may be limited, see documentation of dc_search_msgs()
                    // (formatting may be "1.000" or "1,000", so just skip the first digit)
                    ret = ret.replacingOccurrences(of: "000", with: "000+")
                }
                return ret
            }
        }
        return nil
    }

    func chatIdFor(section: Int, row: Int) -> Int? {
        let cellData = cellDataFor(section: section, row: row)
        switch cellData.type {
        case .chat(let data):
            return data.chatId
        case .contact:
            return nil
        case .profile:
            return nil
        }
    }

    func isMessageSearchResult(indexPath: IndexPath) -> Bool {
        if searchActive, searchResultSections.count > indexPath.section {
            switch searchResultSections[indexPath.section] {
            case .messages:
                return true
            case .contacts, .chats:
                return false
            }
        }
        return false
    }

    func chatIdsFor(indexPaths: [IndexPath]?) -> [Int] {
        guard let indexPaths else { return [] }
        var chatIds: [Int] = []
        for indexPath in indexPaths {
            guard let chatId = chatIdFor(section: indexPath.section, row: indexPath.row) else {
                continue
            }
            chatIds.append(chatId)
        }
        return chatIds
    }

    func msgIdFor(row: Int) -> Int? {
        if showSearchResults {
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

    func deleteChats(indexPaths: [IndexPath]?) {
        let chatIds = chatIdsFor(indexPaths: indexPaths)
        for chatId in chatIds {
            deleteChat(chatId: chatId)
        }
    }

    func archiveChatsToggle(indexPaths: [IndexPath]?) {
        let chatIds = chatIdsFor(indexPaths: indexPaths)
        for chatId in chatIds {
            archiveChatToggle(chatId: chatId)
        }
    }

    func pinChatsToggle(indexPaths: [IndexPath]?) {
        let chatIds = chatIdsFor(indexPaths: indexPaths)
        let onlyPinnedChatsSelected = hasOnlyPinnedChatsSelected(chatIds: chatIds)
        for chatId in chatIds {
            pinChat(chatId: chatId, pinned: onlyPinnedChatsSelected)
        }
    }

    func setMuteDurations(in indexPaths: [IndexPath]?, duration: Int) {
        let chatIds = chatIdsFor(indexPaths: indexPaths)
        for chatId in chatIds {
            dcContext.setChatMuteDuration(chatId: chatId, duration: duration)
        }
    }

    func markUnreadSelectedChats(in indexPaths: [IndexPath]?) {
        let chatIds = chatIdsFor(indexPaths: indexPaths)
        for chatId in chatIds {
            dcContext.marknoticedChat(chatId: chatId)
            NotificationManager.removeNotificationsForChat(dcContext: dcContext, chatId: chatId)
        }
    }

    func deleteChat(chatId: Int) {
        dcContext.deleteChat(chatId: chatId)
        if #available(iOS 17.0, *) {
            UserDefaults.shared?.removeChatFromHomescreenWidget(accountId: dcContext.id, chatId: chatId)
        }
        NotificationManager.removeNotificationsForChat(dcContext: dcContext, chatId: chatId)
        INInteraction.delete(with: ["\(dcContext.id).\(chatId)"])
    }

    func archiveChatToggle(chatId: Int) {
        let chat = dcContext.getChat(chatId: chatId)
        let isArchivedBefore = chat.isArchived
        dcContext.archiveChat(chatId: chatId, archive: !isArchivedBefore)
        if !isArchivedBefore {
            NotificationManager.removeNotificationsForChat(dcContext: dcContext, chatId: chatId)
        }
        updateChatList(notifyListener: true)
    }

    func pinChatToggle(chatId: Int) {
        let chat: DcChat = dcContext.getChat(chatId: chatId)
        let pinned = chat.visibility == DC_CHAT_VISIBILITY_PINNED
        pinChat(chatId: chatId, pinned: pinned, notifyListener: true)
    }

    func pinChat(chatId: Int, pinned: Bool, notifyListener: Bool = false) {
        self.dcContext.setChatVisibility(chatId: chatId, visibility: pinned ? DC_CHAT_VISIBILITY_NORMAL : DC_CHAT_VISIBILITY_PINNED)
        updateChatList(notifyListener: notifyListener)
    }

    func hasAnyUnreadChatSelected(in indexPaths: [IndexPath]?) -> Bool {
        let chatIds = chatIdsFor(indexPaths: indexPaths)
        for chatId in chatIds {
            if dcContext.getUnreadMessages(chatId: chatId) > 0 {
                return true
            }
        }
        return false
    }

    func hasAnyUnmutedChatSelected(in indexPaths: [IndexPath]?) -> Bool {
        let chatIds = chatIdsFor(indexPaths: indexPaths)
        for chatId in chatIds {
            if !dcContext.getChat(chatId: chatId).isMuted {
                return true
            }
        }
        return false
    }

    func hasOnlyPinnedChatsSelected(in indexPaths: [IndexPath]?) -> Bool {
        let chatIds = chatIdsFor(indexPaths: indexPaths)
        return hasOnlyPinnedChatsSelected(chatIds: chatIds)
    }

    func hasOnlyPinnedChatsSelected(chatIds: [Int]) -> Bool {
        if chatIds.isEmpty {
            return false
        }

        for chatId in chatIds {
            let chat: DcChat = dcContext.getChat(chatId: chatId)
            if chat.visibility != DC_CHAT_VISIBILITY_PINNED {
                return false
            }
        }
        return true
    }

    func setEditing(_ editing: Bool) {
        isEditing = editing
        if !isEditing && isChatListUpdatePending {
            handleOnChatListUpdate()
        }
    }

    func setPendingChatListUpdate() {
        if isEditing {
            isChatListUpdatePending = true
        }
    }

    // MARK: - avatarCellViewModel factory
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

    func makeMessageCellViewModel(msgId: Int) -> AvatarCellViewModel {
        let msg: DcMsg = dcContext.getMessage(id: msgId)
        let chatId: Int = msg.chatId
        let chat: DcChat = dcContext.getChat(chatId: chatId)
        if !chat.isValid {
            // chat might be deleted and searchResultMessageIds deprecated, so return a dummy view model
            // cleanup of the searchResultMessageIds will be done in message change event handling
            return ChatCellViewModel(
                dcContext: dcContext,
                chatData: ChatCellData(
                    chatId: 0,
                    highlightMsgId: 0,
                    summary: DcLot(nil),
                    unreadMessages: 0
                )
            )
        }
        let summary: DcLot = msg.summary(chat: chat)
        let unreadMessages = dcContext.getUnreadMessages(chatId: chatId)

        let viewModel = ChatCellViewModel(
            dcContext: dcContext,
            chatData: ChatCellData(
                chatId: chatId,
                highlightMsgId: msgId,
                summary: summary,
                unreadMessages: unreadMessages
            )
        )
        let subtitle = viewModel.subtitle
        viewModel.subtitleHighlightIndexes = subtitle.containsExact(subSequence: searchText)
        return viewModel
    }

    // MARK: - search
    private func updateSearchResultSections() {
        var sections: [ChatListSectionType] = []
        if let chatList = searchResultChatList, chatList.length > 0 {
            sections.append(searchResultsChatsSection)
        }
        if !searchResultContactIds.isEmpty {
            sections.append(searchResultsContactsSection)
        }
        if !searchResultMessageIds.isEmpty {
            sections.append(searchResultsMessagesSection)
        }
        searchResultSections = sections
    }

    private func resetSearch() {
        searchResultChatList = nil
        searchResultContactIds = []
        searchResultMessageIds = []
        updateSearchResultSections()
    }

    private func filterContentForSearchText(_ searchText: String) {
        if !searchText.isEmpty {
            filterAndUpdateList(searchText: searchText)
        } else {
            // when search input field empty we show default chatList
            resetSearch()
        }
        handleOnChatListUpdate()
    }

    func filterAndUpdateList(searchText: String) {
        var overallCnt = 0

        // #1 - search for chats with searchPattern in title
        searchResultChatList = dcContext.getChatlist(flags: DC_GCL_NO_SPECIALS, queryString: searchText, queryId: 0)
        if let chatlist = searchResultChatList {
            overallCnt += chatlist.length
        }

        // #2 - search for contacts with searchPattern in name or in email
        if searchText != self.searchText && overallCnt > 0 {
            logger.info("... skipping getContacts and searchMessages, more recent search pending")
            searchResultContactIds = []
            searchResultMessageIds = []
            updateSearchResultSections()
            return
        }

        searchResultContactIds = dcContext.getContacts(flags: DC_GCL_ADD_SELF, queryString: searchText)
        overallCnt += searchResultContactIds.count

        // #3 - search for messages with searchPattern in fulltext
        if searchText != self.searchText && overallCnt > 0 {
            logger.info("... skipping searchMessages, more recent search pending")
            searchResultMessageIds = []
            updateSearchResultSections()
            return
        }

        if searchText.count <= 1 {
            logger.info("... skipping searchMessages, string too short")
            searchResultMessageIds = []
            updateSearchResultSections()
            return
        }

        searchResultMessageIds = dcContext.searchMessages(searchText: searchText)
        updateSearchResultSections()
    }
}

// MARK: UISearchResultUpdating
extension ChatListViewModel: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {

        self.searchText = searchController.searchBar.text ?? ""

        if inBgSearch {
            needsAnotherBgSearch = true
            logger.info("... search call debounced")
        } else {
            inBgSearch = true
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                usleep(100000)
                self?.needsAnotherBgSearch = false
                self?.filterContentForSearchText(self?.searchText ?? "")

                while self?.needsAnotherBgSearch != false {
                    usleep(100000)
                    self?.needsAnotherBgSearch = false
                    logger.info("... executing debounced search call")
                    self?.filterContentForSearchText(self?.searchText ?? "")
                }

                self?.inBgSearch = false
            }
        }
    }
}

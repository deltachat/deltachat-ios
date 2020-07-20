import Foundation
import UIKit
import DcCore

protocol ChatListDelegate: class {
    func onChatSelected(chatId: Int)
}

class ChatListController: UITableViewController {
    let dcContext: DcContext
    let viewModel: ChatListViewModel
    let contactCellReuseIdentifier = "contactCellReuseIdentifier"
    weak var chatListDelegate: ChatListDelegate?

    /// MARK - search

    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = viewModel
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String.localized("search")
        searchController.dimsBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.searchBar.delegate = self
        return searchController
    }()

    init(dcContext: DcContext, chatListDelegate: ChatListDelegate) {
        self.dcContext = dcContext
        self.chatListDelegate = chatListDelegate
        viewModel = ChatListViewModel(dcContext: dcContext)
        super.init(style: .grouped)
        viewModel.onChatListUpdate = handleChatListUpdate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        preferredContentSize = UIScreen.main.bounds.size
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    override func viewDidAppear(_ animated: Bool) {
        navigationItem.hidesSearchBarWhenScrolling = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        //chatList = dcContext.getChatlist(flags: DC_GCL_ADD_ALLDONE_HINT | DC_GCL_FOR_FORWARDING | DC_GCL_NO_SPECIALS, queryString: nil, queryId: 0)
        navigationItem.searchController = searchController
        tableView.register(ChatListCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
        tableView.rowHeight = 64
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 0.0, height: Double.leastNormalMagnitude))
        tableView.tableFooterView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 0.0, height: Double.leastNormalMagnitude))

    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRowsIn(section: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: contactCellReuseIdentifier, for: indexPath) as? ChatListCell else {
            fatalError("could not deque TableViewCell")
        }

        if let chatId = viewModel.getChatId(section: indexPath.section, row: indexPath.row) {
            cell.updateCell(chatId: chatId)
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let chatId = viewModel.getChatId(section: indexPath.section, row: indexPath.row) {
            chatListDelegate?.onChatSelected(chatId: chatId)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
           return viewModel.titleForHeaderIn(section: section)
       }

    func handleChatListUpdate() {
        tableView.reloadData()
    }

}

// MARK: - uisearchbardelegate
extension ChatListController: UISearchBarDelegate {
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        viewModel.beginSearch()
        return true
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // searchBar will be set to "" by system
        viewModel.endSearch()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
           self.tableView.scrollToTop()
        }
    }

    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        tableView.scrollToTop()
        return true
    }
}

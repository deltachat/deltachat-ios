import Foundation
import UIKit
import DcCore

protocol ChatListDelegate: class {
    func onChatSelected(chatId: Int)
}

class ChatListController: UITableViewController {
    let dcContext: DcContext
    var chatList: DcChatlist?
    let contactCellReuseIdentifier = "contactCellReuseIdentifier"
    weak var chatListDelegate: ChatListDelegate?

    /// MARK - search

    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        //searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String.localized("search")
        searchController.dimsBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = true
        return searchController
    }()

    init(dcContext: DcContext, chatListDelegate: ChatListDelegate) {
        self.dcContext = dcContext
        self.chatListDelegate = chatListDelegate
        super.init(style: .grouped)
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
        chatList = dcContext.getChatlist(flags: DC_GCL_ADD_ALLDONE_HINT | DC_GCL_FOR_FORWARDING | DC_GCL_NO_SPECIALS, queryString: nil, queryId: 0)
        navigationItem.searchController = searchController
        tableView.register(ChatListCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
        tableView.rowHeight = 64
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 0.0, height: Double.leastNormalMagnitude))
        tableView.tableFooterView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 0.0, height: Double.leastNormalMagnitude))

    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chatList?.length ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: contactCellReuseIdentifier, for: indexPath) as? ChatListCell else {
            fatalError("could not deque TableViewCell")
        }

        if let chatList = chatList {
            cell.updateCell(chatId: chatList.getChatId(index: indexPath.row))
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let chatList = chatList {
            chatListDelegate?.onChatSelected(chatId: chatList.getChatId(index: indexPath.row))
        }
    }

}

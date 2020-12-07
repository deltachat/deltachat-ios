import UIKit
import DcCore

class DocumentGalleryController: UIViewController {

    private var fileMessageIds: [Int]
    private let dcContext: DcContext

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.register(DocumentGalleryFileCell.self, forCellReuseIdentifier: DocumentGalleryFileCell.reuseIdentifier)
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 60
        return table
    }()

    private lazy var emptyStateView: EmptyStateLabel = {
        let label = EmptyStateLabel()
        label.text = String.localized("tab_docs_empty_hint")
        label.isHidden = true
        return label
    }()

    private lazy var contextMenuConfiguration: ContextMenuConfiguration = {
        let deleteItem = ContextMenuConfiguration.ContextMenuItem(
            title: String.localized("delete"),
            imageNames: ("trash", nil),
            option: .delete,
            action: #selector(GalleryCell.itemDelete(_:)),
            onPerform: { [weak self] indexPath in
                self?.askToDeleteItem(at: indexPath)
            }
        )
        let showInChatItem = ContextMenuConfiguration.ContextMenuItem(
            title: String.localized("show_in_chat"),
            imageNames: ("doc.text.magnifyingglass", nil),
            option: .showInChat,
            action: #selector(GalleryCell.showInChat(_:)),
            onPerform: { [weak self] indexPath in
                self?.redirectToMessage(of: indexPath)
            }
        )

        let config = ContextMenuConfiguration()
        config.setMenu([showInChatItem, deleteItem])
        return config
    }()

    init(context: DcContext, fileMessageIds: [Int]) {
        self.dcContext = context
        self.fileMessageIds = fileMessageIds
        super.init(nibName: nil, bundle: nil)
        self.title = String.localized("files")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
        if fileMessageIds.isEmpty {
            emptyStateView.isHidden = false
        }
    }

    // MARK: - layout
    private func setupSubviews() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        view.addSubview(emptyStateView)
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor).isActive = true
        emptyStateView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor).isActive = true
        emptyStateView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor).isActive = true
        emptyStateView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
    }

    // MARK: - actions
    private func askToDeleteItem(at indexPath: IndexPath) {
        let title = String.localized(stringID: "ask_delete_messages", count: 1)
        let alertController =  UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
        let okAction = UIAlertAction(title: String.localized("delete"), style: .destructive, handler: { [weak self] _ in
            self?.deleteItem(at: indexPath)
        })
        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil)
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }

    private func deleteItem(at indexPath: IndexPath) {
        let msgId = fileMessageIds.remove(at: indexPath.row)
        self.dcContext.deleteMessage(msgId: msgId)
        self.tableView.deleteRows(at: [indexPath], with: .automatic)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension DocumentGalleryController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fileMessageIds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: DocumentGalleryFileCell.reuseIdentifier, for: indexPath)
                as? DocumentGalleryFileCell else {
            return UITableViewCell()
        }
        let msg = DcMsg(id: fileMessageIds[indexPath.row])
        cell.update(msg: msg)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let msgId = fileMessageIds[indexPath.row]
        showPreview(msgId: msgId)
        tableView.deselectRow(at: indexPath, animated: false)
    }

    // MARK: - context menu
    // context menu for iOS 11, 12
    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return contextMenuConfiguration.canPerformAction(action: action)
    }

    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        contextMenuConfiguration.performAction(action: action, indexPath: indexPath)
    }

    // context menu for iOS 13+
    @available(iOS 13, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil,
            actionProvider: { [weak self] _ in
                self?.contextMenuConfiguration.actionProvider(indexPath: indexPath)
            }
        )
    }
}

// MARK: - coordinator
extension DocumentGalleryController {
    func showPreview(msgId: Int) {
        guard let index = fileMessageIds.index(of: msgId) else {
            return
        }
        let previewController = PreviewController(type: .multi(fileMessageIds, index))
        present(previewController, animated: true, completion: nil)
    }

    func redirectToMessage(of indexPath: IndexPath) {
        let msgId = fileMessageIds[indexPath.row]

        guard
            let chatViewController = navigationController?.viewControllers.filter ({ $0 is ChatViewController}).first as? ChatViewController,
            let chatListController = navigationController?.viewControllers.filter({ $0 is ChatListController}).first as? ChatListController
        else {
            safe_fatalError("failt to retrieve chatViewController, chatListController in navigation stack")
            return
        }
        self.navigationController?.viewControllers.remove(at: 1)

        self.navigationController?.pushViewController(chatViewController, animated: true)
        self.navigationController?.setViewControllers([chatListController, chatViewController], animated: false)
        chatViewController.scrollToMessage(msgId: msgId)
    }
}

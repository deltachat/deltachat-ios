import UIKit
import DcCore
import LinkPresentation
import WidgetKit

class FilesViewController: UIViewController {

    public let type1: Int32
    public let type2: Int32
    public let type3: Int32

    private var fileMessageIds: [Int] = []
    private let dcContext: DcContext
    private let chatId: Int

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.register(DocumentGalleryFileCell.self, forCellReuseIdentifier: DocumentGalleryFileCell.reuseIdentifier)
        table.dataSource = self
        table.delegate = self
        table.rowHeight = DocumentGalleryFileCell.cellHeight
        return table
    }()

    private lazy var emptyStateView: EmptyStateLabel = {
        let label = EmptyStateLabel()
        if chatId == 0 {
            if type1 == DC_MSG_WEBXDC {
                label.text = String.localized("all_apps_empty_hint")
            } else if type1 == DC_MSG_FILE {
                label.text = String.localized("all_files_empty_hint")
            } else {
                label.text = String.localized("tab_all_media_empty_hint")
            }
        } else if type1 == DC_MSG_AUDIO {
            label.text = String.localized("tab_audio_empty_hint")
        } else if type1 == DC_MSG_WEBXDC {
            label.text = String.localized("tab_webxdc_empty_hint")
        } else {
            label.text = String.localized("tab_docs_empty_hint")
        }
        label.isHidden = true
        return label
    }()


    init(context: DcContext, chatId: Int, type1: Int32, type2: Int32, type3: Int32, title: String? = nil) {
        self.dcContext = context
        self.chatId = chatId
        self.type1 = type1
        self.type2 = type2
        self.type3 = type3
        super.init(nibName: nil, bundle: nil)
        self.title = title

        NotificationCenter.default.addObserver(self, selector: #selector(FilesViewController.handleMessagesChanged(_:)), name: Event.messagesChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(FilesViewController.handleMessageReadDeliveredFailedReaction(_:)), name: Event.messageReadDeliveredFailedReaction, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(FilesViewController.handleIncomingMessage(_:)), name: Event.incomingMessage, object: nil)

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.refreshDataFromBgThread()
        }
    }

    // MARK: - setup
    private func setupSubviews() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        emptyStateView.addCenteredTo(parentView: view)
    }

    // MARK: - Notifications
    @objc private func handleMessagesChanged(_ notification: Notification) {
        refreshInBg()
    }

    @objc private func handleMessageReadDeliveredFailedReaction(_ notification: Notification) {
        refreshInBg()
    }

    @objc private func handleIncomingMessage(_ notification: Notification) {
        refreshInBg()
    }

    private var inBgRefresh = false
    private var needsAnotherBgRefresh = false
    private func refreshInBg() {
        if inBgRefresh {
            needsAnotherBgRefresh = true
        } else {
            inBgRefresh = true
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                self?.needsAnotherBgRefresh = false
                self?.refreshDataFromBgThread()
                while self?.needsAnotherBgRefresh != false {
                    usleep(500000)
                    self?.needsAnotherBgRefresh = false
                    self?.refreshDataFromBgThread()
                }
                self?.inBgRefresh = false
            }
        }
    }

    private func refreshDataFromBgThread() {
        // may take a moment, should not be called from main thread
        let ids: [Int]
        ids = self.dcContext.getChatMedia(chatId: self.chatId, messageType: self.type1, messageType2: self.type2, messageType3: self.type3).reversed()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.fileMessageIds = ids
            self.emptyStateView.isHidden = !ids.isEmpty
            self.tableView.reloadData()
        }
    }

    // MARK: - actions

    private func askToDeleteItem(at indexPath: IndexPath) {
        let alertController =  UIAlertController(title: String.localized(stringID: "ask_delete_messages", parameter: 1), message: nil, preferredStyle: .safeActionSheet)
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
        if #available(iOS 17.0, *) {
            UserDefaults.shared?.removeWebxdcFromHomescreen(accountId: dcContext.id, messageId: msgId)
        }
        self.tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    func showWebxdcViewFor(message: DcMsg) {
        let webxdcViewController = WebxdcViewController(dcContext: dcContext, messageId: message.id)
        navigationController?.pushViewController(webxdcViewController, animated: true)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension FilesViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fileMessageIds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: DocumentGalleryFileCell.reuseIdentifier, for: indexPath)
                as? DocumentGalleryFileCell else {
            return UITableViewCell()
        }
        let msg = dcContext.getMessage(id: fileMessageIds[indexPath.row])
        cell.update(msg: msg, dcContext: dcContext)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let msgId = fileMessageIds[indexPath.row]
        let message = dcContext.getMessage(id: msgId)
        if message.type == DC_MSG_WEBXDC {
            showWebxdcViewFor(message: message)
        } else {
            showPreview(msgId: msgId)
        }
        tableView.deselectRow(at: indexPath, animated: false)
    }

    // MARK: - context menu
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil,
            actionProvider: { [weak self] _ in
                guard let self else { return nil }

                var children: [UIMenuElement] = [
                    UIAction.menuAction(localizationKey: "show_in_chat", systemImageName: "doc.text.magnifyingglass", with: indexPath, action: redirectToMessage),
                ]

                children.append(contentsOf: [
                    UIAction.menuAction(localizationKey: "menu_share", systemImageName: "square.and.arrow.up", with: indexPath, action: shareAttachment),
                    UIAction.menuAction(localizationKey: "delete", attributes: [.destructive], systemImageName: "trash", with: indexPath, action: askToDeleteItem)
                ])
                let menu = UIMenu(children: children)

                return menu
            }
        )
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory {
            tableView.rowHeight = DocumentGalleryFileCell.cellHeight
        }
    }
}

// MARK: - coordinator
extension FilesViewController {
    func showPreview(msgId: Int) {
        guard let index = fileMessageIds.firstIndex(of: msgId) else {
            return
        }
        let previewController = PreviewController(dcContext: dcContext, type: .multi(fileMessageIds, index))
        navigationController?.pushViewController(previewController, animated: true)
    }

    func redirectToMessage(of indexPath: IndexPath) {
        let msgId = fileMessageIds[indexPath.row]
        let chatId = dcContext.getMessage(id: msgId).chatId

        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.appCoordinator.showChat(chatId: chatId, msgId: msgId, animated: false, clearViewControllerStack: true)
        }
    }

    func shareAttachment(of indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            let msgId = fileMessageIds[indexPath.row]
            Utils.share(message: dcContext.getMessage(id: msgId), parentViewController: self, sourceView: cell.contentView)
        }
    }
}

class WebxdcItemSource: NSObject, UIActivityItemSource {
    var title: String
    var url: URL
    var previewImage: UIImage?

    init(title: String, previewImage: UIImage?, url: URL) {
        self.title = title
        self.url = url
        self.previewImage = previewImage
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return title
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return url
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        if let previewImage {
            metadata.iconProvider = NSItemProvider(object: previewImage)
        }
        metadata.originalURL = url
        return metadata
    }
}

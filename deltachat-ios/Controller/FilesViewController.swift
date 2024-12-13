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
            label.text = String.localized("tab_all_media_empty_hint")
        } else if type1 == DC_MSG_AUDIO {
            label.text = String.localized("tab_audio_empty_hint")
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
    @objc private func askToDeleteItem(_ sender: Any) {
        guard let menuItem = UIMenuController.shared.menuItems?.first as? LegacyMenuItem,
              let indexPath = menuItem.indexPath else { return }

        askToDeleteItem(at: indexPath)
    }

    private func askToDeleteItem(at indexPath: IndexPath) {
        let chat = dcContext.getChat(chatId: chatId)
        let title = chat.isDeviceTalk ?
            String.localized(stringID: "ask_delete_messages_simple", parameter: 1) :
            String.localized(stringID: "ask_delete_messages", parameter: 1)
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
    // context menu for iOS 11, 12

    private func contextMenu(for indexPath: IndexPath) -> [LegacyMenuItem] {
        return [
            LegacyMenuItem(title: String.localized("show_in_chat"), action: #selector(FilesViewController.redirectToMessage(_:)), indexPath: indexPath),
            LegacyMenuItem(title: String.localized("menu_share"), action: #selector(FilesViewController.shareAttachment(_:)), indexPath: indexPath),
            LegacyMenuItem(title: String.localized("delete"), action: #selector(FilesViewController.askToDeleteItem(_:)), indexPath: indexPath)
        ]
    }

    private func prepareContextMenu(indexPath: IndexPath) {
        if #available(iOS 13.0, *) {
            return
        }

        UIMenuController.shared.menuItems = contextMenu(for: indexPath)
        UIMenuController.shared.update()
    }


    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        prepareContextMenu(indexPath: indexPath)
        return true
    }

    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        let actionIsPartOfMenu = contextMenu(for: indexPath).compactMap { $0.action }.first { $0 == action } != nil
        return actionIsPartOfMenu
    }

    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        // Intentionally left blank
    }

    // context menu for iOS 13+
    @available(iOS 13, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil,
            actionProvider: { [weak self] _ in
                guard let self else { return nil }

                var children: [UIMenuElement] = [
                    UIAction.menuAction(localizationKey: "show_in_chat", systemImageName: "doc.text.magnifyingglass", indexPath: indexPath, action: { self.redirectToMessage(of: $0) }),
                ]

                if #available(iOS 15, *),
                   type1 == DC_MSG_WEBXDC {

                    let messageId = self.fileMessageIds[indexPath.row]
                    let appsInWidgetsMessageIds = self.dcContext.shownWidgets().compactMap { $0.messageId }
                    let isOnHomescreen = appsInWidgetsMessageIds.contains(messageId)
                    
                    if isOnHomescreen {
                        children.append(
                            UIAction.menuAction(
                                localizationKey: "ios_remove_from_home_screen",
                                systemImageName: "rectangle.on.rectangle.slash",
                                indexPath: indexPath,
                                action: { _ in
                                    self.dcContext.removeWebxdcFromHomescreen(messageId: messageId)
                                    })
                        )
                    } else {
                        children.append(
                            UIAction.menuAction(
                                localizationKey: "ios_add_to_home_screen",
                                systemImageName: "plus.rectangle.on.rectangle",
                                indexPath: indexPath,
                                action: { _ in
                                    self.dcContext.addWebxdcToHomescreenWidget(messageId: messageId)
                                })
                        )
                    }
                }

                children.append(contentsOf: [
                    UIAction.menuAction(localizationKey: "menu_share", systemImageName: "square.and.arrow.up", indexPath: indexPath, action: { self.shareAttachment(of: $0) }),
                    UIMenu(
                        options: [.displayInline],
                        children: [
                            UIAction.menuAction(localizationKey: "delete", attributes: [.destructive], systemImageName: "trash", indexPath: indexPath, action: { self.askToDeleteItem(at: $0) })
                        ]
                    )
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

    @objc private func redirectToMessage(_ sender: Any) {
        guard let menuItem = UIMenuController.shared.menuItems?.first as? LegacyMenuItem,
              let indexPath = menuItem.indexPath else { return }

        redirectToMessage(of: indexPath)
    }

    func redirectToMessage(of indexPath: IndexPath) {
        let msgId = fileMessageIds[indexPath.row]
        let chatId = dcContext.getMessage(id: msgId).chatId

        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.appCoordinator.showChat(chatId: chatId, msgId: msgId, animated: false, clearViewControllerStack: true)
        }
    }

    @objc private func shareAttachment(_ sender: Any) {
        guard let menuItem = UIMenuController.shared.menuItems?.first as? LegacyMenuItem,
              let indexPath = menuItem.indexPath else { return }

        shareAttachment(of: indexPath)
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

    @available(iOS 13.0, *)
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        if let previewImage = previewImage {
            metadata.iconProvider = NSItemProvider(object: previewImage)
        }
        metadata.originalURL = url
        return metadata
    }
}

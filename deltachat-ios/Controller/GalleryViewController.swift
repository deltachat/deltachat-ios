import UIKit
import DcCore
import QuickLook

class GalleryViewController: UIViewController {

    private let dcContext: DcContext
    private let chatId: Int
    private var mediaMessageIds: [Int] = []
    private var galleryItemCache: [Int: GalleryItem] = [:]
    private let gridDefaultSpacing: CGFloat = 5

    private lazy var gridLayout: GridCollectionViewFlowLayout = {
        let layout = GridCollectionViewFlowLayout()
        layout.minimumLineSpacing = gridDefaultSpacing
        layout.minimumInteritemSpacing = gridDefaultSpacing
        layout.format = .square
        return layout
    }()

    private lazy var grid: UICollectionView = {
        let collection = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
        collection.dataSource = self
        collection.delegate = self
        collection.register(GalleryCell.self, forCellWithReuseIdentifier: GalleryCell.reuseIdentifier)
        collection.contentInset = UIEdgeInsets(top: gridDefaultSpacing, left: gridDefaultSpacing, bottom: gridDefaultSpacing, right: gridDefaultSpacing)
        collection.backgroundColor = DcColors.defaultBackgroundColor
        collection.delaysContentTouches = false
        collection.alwaysBounceVertical = true
        collection.isPrefetchingEnabled = true
        collection.prefetchDataSource = self
        return collection
    }()

    private lazy var timeLabel: GalleryTimeLabel = {
        let view = GalleryTimeLabel()
        view.hide(animated: false)
        return view
    }()

    private lazy var emptyStateView: EmptyStateLabel = {
        let label = EmptyStateLabel()
        label.text = String.localized(chatId == 0 ? "tab_all_media_empty_hint" : "tab_gallery_empty_hint")
        label.isHidden = true
        return label
    }()

    init(context: DcContext, chatId: Int) {
        self.dcContext = context
        self.chatId = chatId
        super.init(nibName: nil, bundle: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(GalleryViewController.handleMessagesChanged(_:)), name: Event.messagesChanged, object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(GalleryViewController.handleMessageReadDeliveredFailedReaction(_:)),
                                               name: Event.messageReadDeliveredFailedReaction,
                                               object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GalleryViewController.handleIncomingMessage(_:)), name: Event.incomingMessage, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
        title = String.localized("images_and_videos")
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.refreshDataFromBgThread()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        if !isOnScreen() {
            galleryItemCache = [:]
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.reloadCollectionViewLayout()
    }

    // MARK: - setup
    private func setupSubviews() {
        view.addSubview(grid)
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        grid.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        grid.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: 0).isActive = true
        grid.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        view.addSubview(timeLabel)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10).isActive = true
        timeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true

        emptyStateView.addCenteredTo(parentView: view)
    }

    // MARK: - Notifications

    @objc private func handleMessageReadDeliveredFailedReaction(_ notification: Notification) {
        refreshInBg()
    }

    @objc private func handleMessagesChanged(_ notification: Notification) {
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
        ids = self.dcContext.getChatMedia(chatId: self.chatId, messageType: DC_MSG_IMAGE, messageType2: DC_MSG_GIF, messageType3: DC_MSG_VIDEO).reversed()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.galleryItemCache = [:]
            self.mediaMessageIds = ids
            self.emptyStateView.isHidden = !ids.isEmpty
            self.grid.reloadData()
        }
    }

    // MARK: - updates
    private func updateFloatingTimeLabel() {
        if let indexPath = grid.indexPathsForVisibleItems.min() {
            let msgId = mediaMessageIds[indexPath.row]
            let msg = dcContext.getMessage(id: msgId)
            timeLabel.update(date: msg.sentDate)
        }
    }
}

extension GalleryViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        indexPaths.forEach {
            if galleryItemCache[$0.row] == nil {
                let message = dcContext.getMessage(id: mediaMessageIds[$0.row])
                let item = GalleryItem(msg: message)
                galleryItemCache[$0.row] = item
            }
        }
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate
extension GalleryViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return mediaMessageIds.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let galleryCell = collectionView.dequeueReusableCell(withReuseIdentifier: GalleryCell.reuseIdentifier, for: indexPath) as? GalleryCell ?? GalleryCell()

        let msgId = mediaMessageIds[indexPath.row]
        var item: GalleryItem
        if let galleryItem = galleryItemCache[indexPath.row] {
            item = galleryItem
        } else {
            let message = dcContext.getMessage(id: msgId)
            let galleryItem = GalleryItem(msg: message)
            galleryItemCache[indexPath.row] = galleryItem
            item = galleryItem
        }
        galleryCell.update(item: item)
        return galleryCell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let previewController = PreviewController(dcContext: dcContext, type: .multi(mediaMessageIds, indexPath.row))
        previewController.delegate = self
        navigationController?.pushViewController(previewController, animated: true)

        collectionView.deselectItem(at: indexPath, animated: true)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        updateFloatingTimeLabel()
        timeLabel.show(animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateFloatingTimeLabel()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        timeLabel.hide(animated: true)
    }

    // MARK: - Actions

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
        let msgId = mediaMessageIds.remove(at: indexPath.row)
        self.dcContext.deleteMessage(msgId: msgId)
        if #available(iOS 17.0, *) {
            UserDefaults.shared?.removeWebxdcFromHomescreen(accountId: dcContext.id, messageId: msgId)
        }
        self.grid.deleteItems(at: [indexPath])
    }

    // MARK: - Context menu

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let galleryCell = collectionView.cellForItem(at: indexPath) as? GalleryCell, let item = galleryCell.item else {
            return nil
        }

        return UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: {
                let contextMenuController = ContextMenuController(msg: item.msg, image: galleryCell.imageView.image)
                return contextMenuController
            },
            actionProvider: { [weak self] _ in
                guard let self else { return nil }

                let menu = UIMenu(
                    children: [
                        UIAction.menuAction(localizationKey: "show_in_chat", systemImageName: "doc.text.magnifyingglass", with: indexPath, action: redirectToMessage),
                        UIAction.menuAction(localizationKey: "delete", attributes: [.destructive], systemImageName: "trash", with: indexPath, action: askToDeleteItem),
                    ]
                )
                return menu
            }
        )
    }
}

// MARK: - grid layout + updates
private extension GalleryViewController {
    func reloadCollectionViewLayout() {
        guard let orientation = UIApplication.shared.orientation else { return }

        // columns specification
        let phonePortrait = 3
        let phoneLandscape = 5
        let padPortrait = 5
        let padLandscape = 8

        let deviceType = UIDevice.current.userInterfaceIdiom

        let gridDisplay: GridDisplay
        if deviceType == .phone {
            if orientation.isPortrait {
                gridDisplay = .grid(columns: phonePortrait)
            } else {
                gridDisplay = .grid(columns: phoneLandscape)
            }
        } else {
            if orientation.isPortrait {
                gridDisplay = .grid(columns: padPortrait)
            } else {
                gridDisplay = .grid(columns: padLandscape)
            }
        }

        gridLayout.display = gridDisplay

        let containerWidth = view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right - 2 * gridDefaultSpacing
        gridLayout.containerWidth = containerWidth
    }
}

// MARK: - coordinator
private extension GalleryViewController {
    func redirectToMessage(of indexPath: IndexPath) {
        let msgId = mediaMessageIds[indexPath.row]
        let chatId = dcContext.getMessage(id: msgId).chatId

        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.appCoordinator.showChat(chatId: chatId, msgId: msgId, animated: false, clearViewControllerStack: true)
        }
    }
}

// MARK: - QLPreviewControllerDataSource
extension GalleryViewController: QLPreviewControllerDelegate {
    func previewController(_ controller: QLPreviewController, transitionViewFor item: QLPreviewItem) -> UIView? {
        let indexPath = IndexPath(row: controller.currentPreviewItemIndex, section: 0)
        return grid.cellForItem(at: indexPath)
    }
}

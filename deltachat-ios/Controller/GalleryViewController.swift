import UIKit
import DcCore
import QuickLook

class GalleryViewController: UIViewController {

    private let dcContext: DcContext
    // MARK: - data
    private let chatId: Int
    private var mediaMessageIds: [Int]
    private var galleryItemCache: [Int: GalleryItem] = [:]

    // MARK: - subview specs
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

    private lazy var contextMenu: ContextMenuProvider = {
        let deleteItem = ContextMenuProvider.ContextMenuItem(
            title: String.localized("delete"),
            imageName: "trash",
            isDestructive: true,
            action: #selector(GalleryCell.itemDelete(_:)),
            onPerform: { [weak self] indexPath in
                self?.askToDeleteItem(at: indexPath)
            }
        )
        let showInChatItem = ContextMenuProvider.ContextMenuItem(
            title: String.localized("show_in_chat"),
            imageName: "doc.text.magnifyingglass",
            action: #selector(GalleryCell.showInChat(_:)),
            onPerform: { [weak self] indexPath in
                self?.redirectToMessage(of: indexPath)
            }
        )

        let config = ContextMenuProvider()
        config.setMenu([showInChatItem, deleteItem])
        return config
    }()

    init(context: DcContext, chatId: Int, mediaMessageIds: [Int]) {
        self.dcContext = context
        self.chatId = chatId
        self.mediaMessageIds = mediaMessageIds
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
        title = String.localized("images_and_videos")
        if mediaMessageIds.isEmpty {
            emptyStateView.isHidden = false
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        setupContextMenuIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        // user leaves view and may not come back soon: clearing cache may free a significant amount of memory
        galleryItemCache = [:]
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

    private func setupContextMenuIfNeeded() {
        UIMenuController.shared.menuItems = contextMenu.menuItems
        UIMenuController.shared.update()
    }

    // MARK: - updates
    private func updateFloatingTimeLabel() {
        if let indexPath = grid.indexPathsForVisibleItems.min() {
            let msgId = mediaMessageIds[indexPath.row]
            let msg = dcContext.getMessage(id: msgId)
            timeLabel.update(date: msg.sentDate)
        }
    }

    // MARK: - actions
    private func askToDeleteItem(at indexPath: IndexPath) {
        let chat = dcContext.getChat(chatId: chatId)
        let title = chat.isDeviceTalk ?
            String.localized(stringID: "ask_delete_messages_simple", count: 1) :
            String.localized(stringID: "ask_delete_messages", count: 1)
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
        let msgId = mediaMessageIds.remove(at: indexPath.row)
        self.dcContext.deleteMessage(msgId: msgId)
        self.grid.deleteItems(at: [indexPath])
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
        UIMenuController.shared.setMenuVisible(false, animated: true)
        return galleryCell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let previewController = PreviewController(dcContext: dcContext, type: .multi(mediaMessageIds, indexPath.row))
        previewController.delegate = self
        navigationController?.pushViewController(previewController, animated: true)

        collectionView.deselectItem(at: indexPath, animated: true)
        UIMenuController.shared.setMenuVisible(false, animated: true)
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

    // MARK: - context menu
    // context menu for iOS 11, 12
    func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return contextMenu.canPerformAction(action: action)
    }

    func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {

        contextMenu.performAction(action: action, indexPath: indexPath)
    }

    // context menu for iOS 13+
    @available(iOS 13, *)
    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint) -> UIContextMenuConfiguration? {
        guard let galleryCell = collectionView.cellForItem(at: indexPath) as? GalleryCell, let item = galleryCell.item else {
            return nil
        }

        return UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: {
                let contextMenuController = ContextMenuController(item: item)
                return contextMenuController
            },
            actionProvider: { [weak self] _ in
                self?.contextMenu.actionProvider(indexPath: indexPath)
            }
        )
    }
}

// MARK: - grid layout + updates
private extension GalleryViewController {
    func reloadCollectionViewLayout() {

        // columns specification
        let phonePortrait = 3
        let phoneLandscape = 5
        let padPortrait = 5
        let padLandscape = 8

        let orientation = UIApplication.shared.statusBarOrientation
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

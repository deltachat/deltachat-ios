import UIKit
import DcCore
import QuickLook

protocol WebxdcSelectorDelegate: AnyObject {
    func onWebxdcSelected(msgId: Int)
    func onWebxdcFromFilesSelected(url: NSURL)
}

class WebxdcSelector: UIViewController {

    private let dcContext: DcContext
    // MARK: - data
    private var deduplicatedMessageIds: [Int] = []
    private var items: [Int: GalleryItem] = [:]

    // MARK: - subview specs
    private let gridDefaultSpacing: CGFloat = 5
    weak var delegate: WebxdcSelectorDelegate?

    private lazy var gridLayout: GridCollectionViewFlowLayout = {
        let layout = GridCollectionViewFlowLayout()
        layout.minimumLineSpacing = gridDefaultSpacing
        layout.minimumInteritemSpacing = gridDefaultSpacing
        layout.format = .rect(ratio: 1.3)
        return layout
    }()

    private lazy var grid: UICollectionView = {
        let collection = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
        collection.dataSource = self
        collection.delegate = self
        collection.register(WebxdcGridCell.self, forCellWithReuseIdentifier: WebxdcGridCell.reuseIdentifier)
        collection.contentInset = UIEdgeInsets(top: gridDefaultSpacing, left: gridDefaultSpacing, bottom: gridDefaultSpacing, right: gridDefaultSpacing)
        collection.backgroundColor = DcColors.defaultBackgroundColor
        collection.delaysContentTouches = false
        collection.alwaysBounceVertical = true
        collection.isPrefetchingEnabled = true
        collection.prefetchDataSource = self
        return collection
    }()

    private lazy var emptyStateView: EmptyStateLabel = {
        let label = EmptyStateLabel()
        label.text = String.localized("one_moment")
        return label
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        let btn = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel,
                                                             target: self,
                                               action: #selector(cancelAction))
        return btn
    }()

    private lazy var filesButton: UIBarButtonItem = {
        let btn = UIBarButtonItem(title: String.localized("files"),
                                  style: .plain,
                                  target: self,
                                  action: #selector(filesAction))
        return btn
    }()

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(dcContext: dcContext, navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    init(context: DcContext) {
        self.dcContext = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
        title = String.localized("webxdc_apps")
        navigationItem.setLeftBarButton(filesButton, animated: false)
        navigationItem.setRightBarButton(cancelButton, animated: false)
        deduplicateWebxdcs()
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
        emptyStateView.addCenteredTo(parentView: view)
    }

    func deduplicateWebxdcs() {
        var deduplicatedMessageHashes: [String: Int] = [:]
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self else { return }
            let mediaMessageIds = dcContext.getChatMedia(chatId: 0, messageType: DC_MSG_WEBXDC, messageType2: 0, messageType3: 0).reversed()
            for id in mediaMessageIds {
                guard let filename = self.dcContext.getMessage(id: id).fileURL else { continue }
                if let hash = try? NSData(contentsOf: filename).sha1() {
                    DispatchQueue.main.async {
                        if deduplicatedMessageHashes[hash] == nil {
                            deduplicatedMessageHashes[hash] = id
                            self.deduplicatedMessageIds.append(id)
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                if self.deduplicatedMessageIds.isEmpty {
                    self.emptyStateView.text = String.localized("webxdc_selector_empty_hint")
                } else {
                    self.emptyStateView.isHidden = true
                }
                self.grid.reloadData()
            }
        }
    }
    
    @objc func cancelAction() {
        dismiss(animated: true, completion: nil)
    }

    @objc func filesAction() {
        mediaPicker?.showDocumentLibrary()
    }
}

extension WebxdcSelector: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        indexPaths.forEach { if items[$0.row] == nil {
            let message = dcContext.getMessage(id: deduplicatedMessageIds[$0.row])
            let item = GalleryItem(msg: message)
            items[$0.row] = item
        }}
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate
extension WebxdcSelector: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return deduplicatedMessageIds.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let webxdcGridCell = collectionView.dequeueReusableCell(
                withReuseIdentifier: WebxdcGridCell.reuseIdentifier,
                for: indexPath) as? WebxdcGridCell else {
            return UICollectionViewCell()
        }

        let msgId = deduplicatedMessageIds[indexPath.row]
        var item: GalleryItem
        if let galleryItem = items[indexPath.row] {
            item = galleryItem
        } else {
            let message = dcContext.getMessage(id: msgId)
            let galleryItem = GalleryItem(msg: message)
            items[indexPath.row] = galleryItem
            item = galleryItem
        }
        webxdcGridCell.update(item: item)
        return webxdcGridCell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let msgId = deduplicatedMessageIds[indexPath.row]
        delegate?.onWebxdcSelected(msgId: msgId)
        collectionView.deselectItem(at: indexPath, animated: true)
        self.dismiss(animated: true, completion: nil)
    }
}

// MARK: - grid layout + updates
private extension WebxdcSelector {
    func reloadCollectionViewLayout() {
        guard let orientation = UIApplication.shared.orientation else { return }

        // columns specification
        let phonePortrait = 3
        let phoneLandscape = 4
        let padPortrait = 5
        let padLandscape = 8

        let deviceType = UIDevice.current.userInterfaceIdiom

        var gridDisplay: GridDisplay?
        if deviceType == .phone {
            if orientation.isPortrait {
                gridDisplay = .grid(columns: phonePortrait)
            } else {
                gridDisplay = .grid(columns: phoneLandscape)
            }
        } else if deviceType == .pad {
            if orientation.isPortrait {
                gridDisplay = .grid(columns: padPortrait)
            } else {
                gridDisplay = .grid(columns: padLandscape)
            }
        }

        if let gridDisplay = gridDisplay {
            gridLayout.display = gridDisplay
        } else {
            safe_fatalError("undefined format")
        }
        let containerWidth = view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right - 2 * gridDefaultSpacing
        gridLayout.containerWidth = containerWidth
    }
}

extension WebxdcSelector: MediaPickerDelegate {
    func onImageSelected(image: UIImage) {}

    func onDocumentSelected(url: NSURL) {
        delegate?.onWebxdcFromFilesSelected(url: url)
        dismiss(animated: true)
    }
}

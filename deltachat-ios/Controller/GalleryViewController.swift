import UIKit
import DcCore
import SDWebImage

class GalleryViewController: UIViewController {

    // MARK: - data
    private let mediaMessageIds: [Int]
    private var items: [Int: GalleryItem] = [:]

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
        label.text = String.localized("tab_gallery_empty_hint")
        label.isHidden = true
        return label
    }()

    init(mediaMessageIds: [Int]) {
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
        title = String.localized("gallery")
        if mediaMessageIds.isEmpty {
            emptyStateView.isHidden = false
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        grid.reloadData()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.reloadCollectionViewLayout()
    }

    override func viewWillDisappear(_ animated: Bool) {
        ThumbnailCache.shared.clearCache()
    }

    // MARK: - setup
    private func setupSubviews() {
        view.addSubview(grid)
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        grid.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        grid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        grid.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        view.addSubview(timeLabel)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10).isActive = true
        timeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true

        view.addSubview(emptyStateView)
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor).isActive = true
        emptyStateView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor).isActive = true
        emptyStateView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor).isActive = true
        emptyStateView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
    }

    // MARK: - updates
    private func updateFloatingTimeLabel() {
        if let indexPath = grid.indexPathsForVisibleItems.min() {
            let msgId = mediaMessageIds[indexPath.row]
            let msg = DcMsg(id: msgId)
            timeLabel.update(date: msg.sentDate)
        }
    }
}

extension GalleryViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
         indexPaths.forEach { if items[$0.row] == nil {
            let item = GalleryItem(msgId: mediaMessageIds[$0.row])
            items[$0.row] = item
        }}
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
        guard let galleryCell = collectionView.dequeueReusableCell(
            withReuseIdentifier: GalleryCell.reuseIdentifier,
            for: indexPath) as? GalleryCell else {
            return UICollectionViewCell()
        }

        let msgId = mediaMessageIds[indexPath.row]
        var item: GalleryItem
        if let galleryItem = items[indexPath.row] {
            item = galleryItem
        } else {
            let galleryItem = GalleryItem(msgId: msgId)
            items[indexPath.row] = galleryItem
            item = galleryItem
        }
        galleryCell.update(item: item)
        return galleryCell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let msgId = mediaMessageIds[indexPath.row]
        showPreview(msgId: msgId)
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
}

// MARK: - grid layout + updates
private extension GalleryViewController {
    func reloadCollectionViewLayout() {

        // columns specification
        let phonePortrait = 3
        let phoneLandscape = 4
        let padPortrait = 5
        let padLandscape = 8

        let orientation = UIApplication.shared.statusBarOrientation
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

// MARK: - coordinator
extension GalleryViewController {
    func showPreview(msgId: Int) {
        guard let index = mediaMessageIds.index(of: msgId) else {
            return
        }

        let mediaUrls = mediaMessageIds.compactMap {
            return DcMsg(id: $0).fileURL
        }
        let previewController = PreviewController(currentIndex: index, urls: mediaUrls)
        present(previewController, animated: true, completion: nil)
    }
}

class GalleryItem {

    var onImageLoaded: ((UIImage?) -> Void)?
    var onGifLoaded: ((SDAnimatedImage?) -> Void)?

    var msg: DcMsg

    var msgViewType: MessageViewType? {
        return msg.viewtype
    }

    var fileUrl: URL? {
        return msg.fileURL
    }

    var thumbnailImage: UIImage? {
        willSet {
           onImageLoaded?(newValue)
        }
    }

    var gifImage: SDAnimatedImage? {
        willSet {
            print("onGifLoaded")
            onGifLoaded?(newValue)
        }
    }

    var showPlayButton: Bool {
        switch msg.viewtype {
        case .video:
            return true
        default:
            return false
        }
    }

    init(msgId: Int) {
        self.msg = DcMsg(id: msgId)

        if let key = msg.fileURL?.absoluteString, let image = ThumbnailCache.shared.restoreImage(key: key) {
            self.thumbnailImage = image
        } else {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        guard let viewtype = msg.viewtype, let url = msg.fileURL else {
            return
        }
        switch viewtype {
        case .image:
            thumbnailImage = msg.image
        case .video:
            loadVideoThumbnail(from: url)
        case .gif:
            loadGifThumbnail(from: url)
        default:
           safe_fatalError("unsupported viewtype - viewtype \(viewtype) not supported.")
        }
    }

    private func loadGifThumbnail(from url: URL) {
        guard let imageData = try? Data(contentsOf: url) else {
            return
        }
        self.gifImage = SDAnimatedImage(data: imageData)


        /*
        DispatchQueue.global(qos: .background).async {
            let gifThumbnail = self.gifThumbnail(url: url)
            DispatchQueue.main.async { [weak self] in
                self?.thumbnailImage = gifThumbnail
                if let image = gifThumbnail {
                    ThumbnailCache.shared.storeImage(image: image, key: url.absoluteString)
                }
            }
        }
        */
    }

    private func loadVideoThumbnail(from url: URL) {
        DispatchQueue.global(qos: .background).async {
            let thumbnailImage = DcUtils.generateThumbnailFromVideo(url: url)
            DispatchQueue.main.async { [weak self] in
                self?.thumbnailImage = thumbnailImage
                if let image = thumbnailImage {
                    ThumbnailCache.shared.storeImage(image: image, key: url.absoluteString)
                }
            }
        }
    }

    private func gifThumbnail(url: URL) -> UIImage? {
        return getGifSequence(url: url)?.first ?? nil
    }

    private func getGifSequence(url: URL) -> [UIImage]? {

        guard let imageData = try? Data(contentsOf: url) else {
            return nil
        }

        let gifOptions = [
            kCGImageSourceShouldAllowFloat as String: true as NSNumber,
            kCGImageSourceCreateThumbnailWithTransform as String: true as NSNumber,
            kCGImageSourceCreateThumbnailFromImageAlways as String: true as NSNumber
            ] as CFDictionary

        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, gifOptions) else {
            debugPrint("Cannot create image source with data!")
            return nil
        }

        let framesCount = CGImageSourceGetCount(imageSource)
        var frameList = [UIImage]()

        for index in 0 ..< framesCount {
            if let cgImageRef = CGImageSourceCreateImageAtIndex(imageSource, index, nil) {
                let uiImageRef = UIImage(cgImage: cgImageRef)
                frameList.append(uiImageRef)
            }
        }
        return frameList
    }
}

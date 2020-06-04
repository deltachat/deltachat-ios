import UIKit
import DcCore

class GalleryViewController: UIViewController {

    // MARK: - data
    private let mediaMessageIds: [Int]

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
        collection.backgroundColor = .white
        collection.delaysContentTouches = false
        collection.alwaysBounceVertical = true
        return collection
    }()

    private lazy var timeLabel: GalleryTimeLabel = {
        let view = GalleryTimeLabel()
        view.hide(animated: false)
        return view
    }()

    private lazy var emptyStateView: EmptyStateLabel = {
        let label = EmptyStateLabel()
        label.text = String.localized("chat_gallery_empty_state")
        label.isHidden = true
        return label
    }()

    init(mediaMessageIds: [Int]) {
        self.mediaMessageIds = mediaMessageIds.reversed()
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

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate
extension GalleryViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

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
        let msg = DcMsg(id: msgId)
        galleryCell.update(msg: msg)
        return galleryCell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let msgId = mediaMessageIds[indexPath.row]
        showPreview(msgId: msgId)
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
        let phonePortrait = 2
        let phoneLandscape = 3
        let padPortrait = 4
        let padLandscape = 6

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
        let msg = DcMsg(id: msgId)
        guard let url = msg.fileURL, let index = mediaMessageIds.index(of: msgId) else {
            return
        }
        let olderUrls: [URL] = msg.previousMediaURLs().reversed()
        let newerUrls: [URL] = msg.nextMediaURLs().reversed()
        // these are the files user will be able to swipe trough
        let mediaUrls: [URL] = newerUrls + [url] + olderUrls
        let previewController = PreviewController(currentIndex: index, urls: mediaUrls)
        present(previewController, animated: true, completion: nil)
    }
}

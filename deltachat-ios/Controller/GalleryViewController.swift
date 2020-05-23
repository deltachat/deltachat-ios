import UIKit
import DcCore

class GalleryViewController: UIViewController {

    private struct GallerySection {
        var headerTitle: String {
            return String.localized(timeBucket.translationKey)
        }
        let timeBucket: TimeBucket
        let msgIds: [Int]
    }

    // MARK: - data
    private let mediaMessageIds: [Int]
    private var gridSections: [GallerySection] = []

    // MARK: - subview specs
    private lazy var gridLayout: GridCollectionViewFlowLayout = {
        let layout = GridCollectionViewFlowLayout()
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.format = .square
        return layout
    }()

    private lazy var grid: UICollectionView = {
        let collection = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
        collection.dataSource = self
        collection.delegate = self
        collection.register(GalleryCell.self, forCellWithReuseIdentifier: GalleryCell.reuseIdentifier)
        collection.register(
            GalleryGridSectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: GalleryGridSectionHeader.reuseIdentifier
        )
        collection.contentInset = UIEdgeInsets(top: 0, left: gridInsets, bottom: 0, right: gridInsets)
        collection.backgroundColor = .white
        collection.delaysContentTouches = false
        return collection
    }()

    private let gridInsets: CGFloat = 10

    init(mediaMessageIds: [Int]) {
        self.mediaMessageIds = mediaMessageIds
        super.init(nibName: nil, bundle: nil)
        self.gridSections = processData(msgIds: mediaMessageIds)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
        title = String.localized("gallery")
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
    }

    // MARK: - data processing + update
    private func processData(msgIds: [Int]) -> [GallerySection] {

        var buckets: [TimeBucket: [Int]] = [:]

        msgIds.forEach { msgId in
            let msg = DcMsg(id: msgId)
            let date: Date = msg.sentDate
            let msgBucket = TimeBucket.bucket(for: date)

            if buckets[msgBucket] != nil {
                buckets[msgBucket]?.append(msgId)
            } else {
                buckets[msgBucket] = [msgId]
            }
        }

        var sections: [GallerySection] = []
        TimeBucket.allCases.forEach { bucket in
            if let msgIds = buckets[bucket] {
                sections.append(GallerySection(timeBucket: bucket, msgIds: msgIds))
            }
        }
        return sections
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate
extension GalleryViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return gridSections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return gridSections[section].msgIds.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let mediaCell = collectionView.dequeueReusableCell(
            withReuseIdentifier: GalleryCell.reuseIdentifier,
            for: indexPath) as? GalleryCell else {
            return UICollectionViewCell()
        }
        let msg = DcMsg(id: mediaMessageIds[indexPath.row])
        mediaCell.update(msg: msg)
        // cell update
        return mediaCell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: GalleryGridSectionHeader.reuseIdentifier,
            for: indexPath
            ) as? GalleryGridSectionHeader {
            header.text = gridSections[indexPath.section].headerTitle
            header.leadingMargin = gridInsets // to have grid and header equally aligned
            return header
        }
        return UICollectionReusableView()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let msgId = gridSections[indexPath.section].msgIds[indexPath.row]
        showPreview(msgId: msgId)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width - 2 * gridInsets, height: 32)
    }
}

// MARK: - update layout
extension GalleryViewController {
    private func reloadCollectionViewLayout() {

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
        let containerWidth = view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right - 2 * gridInsets
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
        let previousUrls: [URL] = msg.previousMediaURLs()
        let nextUrls: [URL] = msg.nextMediaURLs()
        // these are the files user will be able to swipe trough
        let mediaUrls: [URL] = previousUrls + [url] + nextUrls
        let previewController = PreviewController(currentIndex: index, urls: mediaUrls)
        present(previewController, animated: true, completion: nil)
    }
}

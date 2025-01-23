import UIKit
import DcCore
import QuickLook

protocol WebxdcSelectorDelegate: AnyObject {
    func onWebxdcFromFilesSelected(url: URL)
}

// TODO: Rewrite
class RecentWebxdcAppsViewController: UIViewController {

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
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(WebxdcGridCell.self, forCellWithReuseIdentifier: WebxdcGridCell.reuseIdentifier)
        collectionView.contentInset = UIEdgeInsets(top: gridDefaultSpacing, left: gridDefaultSpacing, bottom: gridDefaultSpacing, right: gridDefaultSpacing)
        collectionView.backgroundColor = DcColors.defaultBackgroundColor
        collectionView.delaysContentTouches = false
        collectionView.alwaysBounceVertical = true
        collectionView.isPrefetchingEnabled = true
        collectionView.prefetchDataSource = self
        return collectionView
    }()

    private lazy var emptyStateView: EmptyStateLabel = {
        let label = EmptyStateLabel()
        label.text = String.localized("one_moment")
        return label
    }()

    init(context: DcContext) {
        self.dcContext = context
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .systemBackground
        setupSubviews()
        deduplicateWebxdcs()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - setup
    private func setupSubviews() {
        view.addSubview(grid)
        let constraints = [
            grid.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            grid.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: grid.safeAreaLayoutGuide.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: grid.safeAreaLayoutGuide.bottomAnchor),
        ]

        NSLayoutConstraint.activate(constraints)

        emptyStateView.addCenteredTo(parentView: view)
    }

    func deduplicateWebxdcs() {
        var deduplicatedMessageHashes: [String: Int] = [:]
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self else { return }
            let mediaMessageIds = dcContext.getChatMedia(chatId: 0, messageType: DC_MSG_WEBXDC, messageType2: 0, messageType3: 0).reversed()
            for id in mediaMessageIds {
                guard let filename = self.dcContext.getMessage(id: id).fileURL else { continue }
                if let hash = try? NSData(contentsOf: filename).sha1(), deduplicatedMessageHashes[hash] == nil {
                    deduplicatedMessageHashes[hash] = id
                    self.deduplicatedMessageIds.append(id)
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

extension RecentWebxdcAppsViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        indexPaths.forEach { if items[$0.row] == nil {
            let message = dcContext.getMessage(id: deduplicatedMessageIds[$0.row])
            let item = GalleryItem(msg: message)
            items[$0.row] = item
        }}
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate
extension RecentWebxdcAppsViewController: UICollectionViewDataSource, UICollectionViewDelegate {
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
        let message = dcContext.getMessage(id: msgId)
        if let fileURL = message.fileURL {
            delegate?.onWebxdcFromFilesSelected(url: fileURL)
        }
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

import UIKit
import DcCore
import QuickLook

protocol RecentWebxdcAppsViewControllerDelegate: AnyObject {
    func webxdcFileSelected(_ viewController: RecentWebxdcAppsViewController, url: URL)
}

class RecentWebxdcAppsViewController: UIViewController {
    private let dcContext: DcContext
    private var deduplicatedMessageIds: [Int] = []
    private var items: [Int: GalleryItem] = [:]

    weak var delegate: RecentWebxdcAppsViewControllerDelegate?

    private let collectionView: UICollectionView
    private let emptyStateLabel: EmptyStateLabel

    init(context: DcContext) {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: Self.layout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(RecentWebxdcAppsCell.self, forCellWithReuseIdentifier: RecentWebxdcAppsCell.reuseIdentifier)
        collectionView.backgroundColor = DcColors.defaultBackgroundColor
        collectionView.delaysContentTouches = false
        collectionView.alwaysBounceVertical = true
        emptyStateLabel = EmptyStateLabel(text: String.localized("one_moment"))

        self.dcContext = context
        super.init(nibName: nil, bundle: nil)

        collectionView.dataSource = self
        collectionView.delegate = self
        view.backgroundColor = .systemBackground
        view.addSubview(collectionView)

        setupConstraints()
        deduplicateWebxdcs()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - setup
    private func setupConstraints() {
        let constraints = [
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),
            view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor),
        ]

        NSLayoutConstraint.activate(constraints)

        emptyStateLabel.addCenteredTo(parentView: view)
    }

    private static func layout() -> UICollectionViewCompositionalLayout {

        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemsPerRow: Int
            if UIDevice.current.userInterfaceIdiom == .phone {
                if UIApplication.shared.orientation == .portrait {
                    itemsPerRow = 4
                } else { // landscape
                    itemsPerRow = 8
                }
            } else {
                itemsPerRow = 6
            }
            let fractionalWidth: CGFloat = 1 / CGFloat(itemsPerRow)

            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(fractionalWidth), heightDimension: .fractionalHeight(1))
            let layoutItem = NSCollectionLayoutItem(layoutSize: itemSize)
            layoutItem.contentInsets = .init(top: 4, leading: 4, bottom: 4, trailing: 4)

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalWidth(fractionalWidth * 1.3))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [layoutItem])

            let section = NSCollectionLayoutSection(group: group)
            return section
        }

        return layout
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

            DispatchQueue.main.async {
                if self.deduplicatedMessageIds.isEmpty {
                    self.emptyStateLabel.text = String.localized("all_apps_empty_hint")
                } else {
                    self.emptyStateLabel.isHidden = true
                }
                self.collectionView.reloadData()
            }
        }
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate
extension RecentWebxdcAppsViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return deduplicatedMessageIds.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: RecentWebxdcAppsCell.reuseIdentifier,
                for: indexPath) as? RecentWebxdcAppsCell else {
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
        cell.update(item: item)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let msgId = deduplicatedMessageIds[indexPath.row]
        let message = dcContext.getMessage(id: msgId)
        if let fileURL = message.fileURL {
            delegate?.webxdcFileSelected(self, url: fileURL)
        }
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

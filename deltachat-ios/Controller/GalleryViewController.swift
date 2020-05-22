import UIKit
import DcCore

class GalleryViewController: UIViewController {

    private struct GallerySection {
        let headerTitle: String?
        let msgIds: [Int]
    }

    private let mediaMessageIds: [Int]

    private var gridSections: [GallerySection] = []

    private lazy var grid: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 50, height: 50)
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.dataSource = self
        collection.delegate = self
        collection.register(MediaCell.self, forCellWithReuseIdentifier: MediaCell.reuseIdentifier)
        collection.register(
            GalleryGridSectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: GalleryGridSectionHeader.reuseIdentifier
        )
        collection.backgroundColor = .white
        return collection
    }()

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
    }

    override func viewWillAppear(_ animated: Bool) {
        grid.reloadData()
    }

    // MARK: - setup
    private func setupSubviews() {
        view.addSubview(grid)
        grid.translatesAutoresizingMaskIntoConstraints = false

        grid.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        grid.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        grid.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        grid.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    // MARK: - data processing + update
    private func processData(msgIds: [Int]) -> [GallerySection] {
        let section = GallerySection(headerTitle: String.localized("today"), msgIds: msgIds)
        return [section]
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
        let mediaCell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCell.reuseIdentifier, for: indexPath) as! MediaCell
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
            return header
        }
        return UICollectionReusableView()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 40)
    }
}

class MediaCell: UICollectionViewCell {
    static let reuseIdentifier = "media_cell"

    var imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0).isActive = true
        imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0).isActive = true
        imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0).isActive = true
        imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0).isActive = true
    }

    func update(msg: DcMsg) {
        guard let image = msg.image else {
            return
        }
        imageView.image = image
    }
}

class GalleryGridSectionHeader: UICollectionReusableView {
    static let reuseIdentifier = "gallery_grid_section_header"

    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = DcColors.grayDateColor
        return label
    }()

    var text: String? {
        set {
            label.text = newValue?.uppercased()
        }
        get {
            return label.text
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
        backgroundColor = .white
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 0).isActive = true
        label.topAnchor.constraint(equalTo: topAnchor, constant: 0).isActive = true
        label.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: 0).isActive = true
        label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0).isActive = true
    }
}

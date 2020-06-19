import UIKit
import DcCore

class DocumentGalleryController: UIViewController {

    private let fileMessageIds: [Int]

    private lazy var tableViews: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.register(FileTableViewCell.self, forCellReuseIdentifier: FileTableViewCell.reuseIdentifier)
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 60
        return table
    }()

    init(fileMessageIds: [Int]) {
        self.fileMessageIds = fileMessageIds
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
    }

    // MARK: - layout
    private func setupSubviews() {
        view.addSubview(tableViews)
        tableViews.translatesAutoresizingMaskIntoConstraints = false
        tableViews.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        tableViews.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableViews.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        tableViews.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension DocumentGalleryController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fileMessageIds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: FileTableViewCell.reuseIdentifier, for: indexPath) as? FileTableViewCell else {
            return UITableViewCell()
        }
        let msg = DcMsg(id: fileMessageIds[indexPath.row])
        cell.update(msg: msg)
        return cell
    }
}

class FileTableViewCell: UITableViewCell {

    static let reuseIdentifier = "file_table_view_cell"

    private let fileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        fileImageView.image = nil
        detailTextLabel?.text = nil
        textLabel?.text = nil
    }

    // MARK: - layout
    private func setupSubviews() {
        guard let textLabel = textLabel, let detailTextLabel = detailTextLabel else { return }

        contentView.addSubview(fileImageView)
        fileImageView.translatesAutoresizingMaskIntoConstraints = false
        fileImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0).isActive = true
        fileImageView.heightAnchor.constraint(lessThanOrEqualTo: contentView.heightAnchor, multiplier: 0.9).isActive = true
        fileImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 0).isActive = true
        fileImageView.widthAnchor.constraint(equalToConstant: 50).isActive = true
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        detailTextLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.leadingAnchor.constraint(equalTo: fileImageView.trailingAnchor, constant: 10).isActive = true
        textLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 0).isActive = true
        textLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor, constant: 0).isActive = true
        detailTextLabel.leadingAnchor.constraint(equalTo: textLabel.leadingAnchor, constant: 0).isActive = true
        detailTextLabel.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 0).isActive = true
        detailTextLabel.trailingAnchor.constraint(equalTo: textLabel.trailingAnchor, constant: 0).isActive = true
        detailTextLabel.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: 0).isActive = true
    }

    func update(msg: DcMsg) {
        switch msg.kind {
        case .fileText(let mediaItem):
            if let url = mediaItem.url {
                let controller = UIDocumentInteractionController(url: url)
                fileImageView.image = controller.icons.first ?? mediaItem.placeholderImage
            } else {
                fileImageView.image = mediaItem.placeholderImage
            }
            textLabel?.text = msg.filename
            detailTextLabel?.attributedText = mediaItem.text?[MediaItemConstants.mediaSubtitle]
        default:
            break
        }
        /*
        if let fileUrl = msg.fileURL {
            let controller = UIDocumentInteractionController(url: fileUrl)
            cell.imageView?.image = controller.icons.first
        }
        if let fileName = msg.filename {
            let messageKind = msg.createFileMessage(text: fileName)
            switch messageKind {
            case .fileText(let mediaItem):
                if let title = mediaItem.text?[MediaItemConstants.mediaTitle] {
                    cell.textLabel?.attributedText = title
                    cell.textLabel?.makeBorder(color: .yellow)
                }
                if let subtitle = mediaItem.text?[MediaItemConstants.mediaSubtitle] {
                    cell.detailTextLabel?.attributedText = subtitle
                    cell.detailTextLabel?.makeBorder()
                }
            default:
                break
            }
        }
        */
    }




}

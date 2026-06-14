import UIKit

public protocol ChatListEditingBarDelegate: AnyObject {
    func onDeleteButtonPressed()
    func onArchiveButtonPressed()
    func onMorePressed() -> UIMenu
}

class ChatListEditingBar: UIView {

    weak var delegate: ChatListEditingBarDelegate?

    var showArchive: Bool? {
        didSet {
            guard let showArchive = showArchive else { return }
            let button = archiveButton.customView as? UIButton
            let icon = showArchive ? "tray.and.arrow.down" : "tray.and.arrow.up"
            button?.setImage(UIImage(systemName: icon), for: .normal)
            let title = showArchive ? "archive" : "unarchive"
            button?.setTitle(String.localized(title), for: .normal)
        }
    }

    private lazy var deleteButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(deleteButtonPressed)
        )
        button.tintColor = .systemRed
        button.accessibilityLabel = String.localized("delete")
        return button
    }()

    private lazy var archiveButton: UIBarButtonItem = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "tray.and.arrow.down"), for: .normal)
        button.setTitle(String.localized("archive"), for: .normal)
        var configuration = UIButton.Configuration.plain()
        configuration.imagePadding = 10
        button.configuration = configuration
        // TODO: test if i need this
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.addTarget(self, action: #selector(archiveButtonPressed), for: .touchUpInside)
        return UIBarButtonItem(customView: button)
    }()

    private lazy var moreButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: UIMenu(children: [
                UIDeferredMenuElement.uncached({ [weak self] completion in
                    completion(self?.delegate?.onMorePressed().children ?? [])
                })
            ])
        )
        button.accessibilityLabel = String.localized("menu_more_options")
        return button
    }()

    private lazy var toolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.items = [archiveButton, .flexibleSpace(), deleteButton, moreButton]
        return toolbar
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureSubviews() {
        addSubview(toolbar)
        toolbar.fillSuperviewAvoidingSafeAreaAndKeyboard()
    }

    @objc func deleteButtonPressed() {
        delegate?.onDeleteButtonPressed()
    }

    @objc func archiveButtonPressed() {
        delegate?.onArchiveButtonPressed()
    }
}

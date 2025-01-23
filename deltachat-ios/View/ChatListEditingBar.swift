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
            let imageName = showArchive ? "tray.and.arrow.down" : "tray.and.arrow.up"
            let description = showArchive ? String.localized("archive") : String.localized("unarchive")
            configureButtonLayout(archiveButton, imageName: imageName, imageDescription: description, showImageAndText: true)
        }
    }

    private lazy var blurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var mainContentView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [archiveButton, UIView(), deleteButton, moreButton])
        view.axis = .horizontal
        view.distribution = .fill
        view.alignment = .fill
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var deleteButton: UIButton = {
        return createUIButton(imageName: "trash", imageDescription: String.localized("delete"), tintColor: .systemRed)
    }()

    private lazy var archiveButton: UIButton = {
        return createUIButton(imageName: "tray.and.arrow.down", imageDescription: String.localized("archive"))
    }()

    private lazy var moreButton: UIButton = {
        return createUIButton(imageName: "ellipsis.circle", imageDescription: String.localized("menu_more_options"))
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createUIButton(imageName: String, imageDescription: String, tintColor: UIColor = .systemBlue) -> UIButton {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        configureButtonLayout(button, imageName: imageName, imageDescription: imageDescription, tintColor: tintColor)
        return button
    }
    
    private func configureButtonLayout(_ button: UIButton, imageName: String, imageDescription: String, tintColor: UIColor = .systemBlue, showImageAndText: Bool = false) {
        button.setImage(UIImage(systemName: imageName), for: .normal)
        button.tintColor = tintColor
        if showImageAndText {
            button.setTitle(imageDescription, for: .normal)
            button.setTitleColor(tintColor, for: .normal)
            button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
            button.fixImageAndTitleSpacing()
        }
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        button.accessibilityLabel = imageDescription
    }
    
    private func configureSubviews() {
        self.addSubview(blurView)
        self.addSubview(mainContentView)
        blurView.fillSuperview()
        addConstraints([
            mainContentView.constraintAlignTopTo(self),
            mainContentView.constraintAlignLeadingTo(self, paddingLeading: 8),
            mainContentView.constraintAlignTrailingTo(self, paddingTrailing: 8),
            mainContentView.constraintAlignBottomTo(self, paddingBottom: Utils.getSafeBottomLayoutInset())
        ])

        let deleteBtnGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(deleteButtonPressed))
        deleteBtnGestureRecognizer.numberOfTapsRequired = 1
        deleteButton.addGestureRecognizer(deleteBtnGestureRecognizer)

        let archiveBtnGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(archiveButtonPressed))
        archiveBtnGestureRecognizer.numberOfTapsRequired = 1
        archiveButton.addGestureRecognizer(archiveBtnGestureRecognizer)

        moreButton.showsMenuAsPrimaryAction = true
        moreButton.menu = UIMenu() // otherwise .menuActionTriggered is not triggered
        moreButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            moreButton.menu = delegate?.onMorePressed()
        }, for: .menuActionTriggered)
    }

    @objc func deleteButtonPressed() {
        delegate?.onDeleteButtonPressed()
    }

    @objc func archiveButtonPressed() {
        delegate?.onArchiveButtonPressed()
    }
}

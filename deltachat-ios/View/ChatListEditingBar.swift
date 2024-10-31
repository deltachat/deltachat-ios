import UIKit

public protocol ChatListEditingBarDelegate: AnyObject {
    func onDeleteButtonPressed()
    func onArchiveButtonPressed()
    func onMorePressed()
}

class ChatListEditingBar: UIView {

    weak var delegate: ChatListEditingBarDelegate?

    var showArchive: Bool? {
        didSet {
            guard let showArchive = showArchive else { return }
            let description = showArchive ? String.localized("archive") : String.localized("unarchive")
            configureButtonLayout(archiveButton, imageName: nil, imageDescription: description)
        }
    }

    private lazy var blurView: UIVisualEffectView = {
        var blurEffect = UIBlurEffect(style: .light)
        if #available(iOS 13, *) {
            blurEffect = UIBlurEffect(style: .systemMaterial)
        }
        let view = UIVisualEffectView(effect: blurEffect)
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
        return createUIButton(imageName: nil, imageDescription: String.localized("archive"))
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
    
    private func createUIButton(imageName: String?, imageDescription: String, tintColor: UIColor = .systemBlue) -> UIButton {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        configureButtonLayout(button, imageName: imageName, imageDescription: imageDescription, tintColor: tintColor)
        return button
    }
    
    private func configureButtonLayout(_ button: UIButton, imageName: String?, imageDescription: String, tintColor: UIColor = .systemBlue) {
        if let imageName, #available(iOS 13.0, *) {
            button.setImage(UIImage(systemName: imageName), for: .normal)
            button.tintColor = tintColor
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        } else {
            button.setTitle(imageDescription, for: .normal)
            button.setTitleColor(tintColor, for: .normal)
            button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        }
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

        moreButton.addTarget(self, action: #selector(ChatListEditingBar.onMorePressed), for: .touchUpInside)
    }

    @objc func deleteButtonPressed() {
        delegate?.onDeleteButtonPressed()
    }

    @objc func archiveButtonPressed() {
        delegate?.onArchiveButtonPressed()
    }

    @objc func onMorePressed() {
        delegate?.onMorePressed()
    }
}

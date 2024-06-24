import UIKit

public protocol ChatListEditingBarDelegate: AnyObject {
    func onPinButtonPressed()
    func onDeleteButtonPressed()
    func onArchiveButtonPressed()
}

class ChatListEditingBar: UIView {

    weak var delegate: ChatListEditingBarDelegate?

    var showUnpinning: Bool? {
        didSet {
            guard let showUnpinning = showUnpinning else { return }
            let imageName = showUnpinning ? "pin.slash" : "pin"
            let description = showUnpinning ? String.localized("unpin") :  String.localized("pin")
            configureButtonLayout(pinButton, imageName: imageName, imageDescription: description)
        }
    }

    var showArchive: Bool? {
        didSet {
            guard let showArchive = showArchive else { return }
            let imageName = showArchive ? "tray.and.arrow.down" : "tray.and.arrow.up"
            let description = showArchive ? String.localized("archive") : String.localized("unarchive")
            configureButtonLayout(archiveButton, imageName: imageName, imageDescription: description)
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
        let view = UIStackView(arrangedSubviews: [pinButton, archiveButton, deleteButton])
        view.axis = .horizontal
        view.distribution = .fillEqually
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

    private lazy var pinButton: UIButton = {
        return createUIButton(imageName: "pin", imageDescription: String.localized("pin"))
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
        button.isUserInteractionEnabled = true
        button.imageView?.contentMode = .scaleAspectFit
        configureButtonLayout(button, imageName: imageName, imageDescription: imageDescription, tintColor: tintColor)
        return button
    }
    
    private func configureButtonLayout(_ button: UIButton, imageName: String, imageDescription: String, tintColor: UIColor = .systemBlue) {
        if #available(iOS 13.0, *) {
            button.setImage(UIImage(systemName: imageName), for: .normal)
            button.tintColor = tintColor
        } else {
            button.setTitle(imageDescription, for: .normal)
            button.setTitleColor(tintColor, for: .normal)
        }
        button.accessibilityLabel = description
    }

    private func configureSubviews() {
        self.addSubview(blurView)
        self.addSubview(mainContentView)
        blurView.fillSuperview()
        addConstraints([
            mainContentView.constraintAlignTopTo(self),
            mainContentView.constraintAlignLeadingTo(self),
            mainContentView.constraintAlignTrailingTo(self),
            mainContentView.constraintAlignBottomTo(self, paddingBottom: Utils.getSafeBottomLayoutInset())
        ])

        let pinBtnGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(pinButtonPressed))
        pinBtnGestureRecognizer.numberOfTapsRequired = 1
        pinButton.addGestureRecognizer(pinBtnGestureRecognizer)

        let deleteBtnGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(deleteButtonPressed))
        deleteBtnGestureRecognizer.numberOfTapsRequired = 1
        deleteButton.addGestureRecognizer(deleteBtnGestureRecognizer)

        let archiveBtnGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(archiveButtonPressed))
        archiveBtnGestureRecognizer.numberOfTapsRequired = 1
        archiveButton.addGestureRecognizer(archiveBtnGestureRecognizer)
    }

    @objc func pinButtonPressed() {
        delegate?.onPinButtonPressed()
    }

    @objc func deleteButtonPressed() {
        delegate?.onDeleteButtonPressed()
    }

    @objc func archiveButtonPressed() {
        delegate?.onArchiveButtonPressed()
    }

}

import UIKit

public protocol ChatListEditingBarDelegate: class {
    func onPinButtonPressed()
    func onDeleteButtonPressed()
    func onArchiveButtonPressed()
}

class ChatListEditingBar: UIView {

    weak var delegate: ChatListEditingBarDelegate?

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
        let view = UIButton()

        if #available(iOS 13.0, *) {
            view.setImage(UIImage(systemName: "trash"), for: .normal)
            view.tintColor = .systemBlue
        } else {
            view.setTitle(String.localized("delete"), for: .normal)
            view.setTitleColor(.systemBlue, for: .normal)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        view.imageView?.contentMode = .scaleAspectFit
        view.accessibilityLabel = String.localized("delete")
        return view
    }()

    private lazy var archiveButton: UIButton = {
        let view = UIButton()

        if #available(iOS 13.0, *) {
            view.setImage(UIImage(systemName: "tray.and.arrow.down"), for: .normal)
            view.tintColor = .systemBlue
        } else {
            view.setTitle(String.localized("archive"), for: .normal)
            view.setTitleColor(.systemBlue, for: .normal)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        view.imageView?.contentMode = .scaleAspectFit
        view.accessibilityLabel = String.localized("archive")
        return view
    }()

    private lazy var pinButton: UIButton = {
        let view = UIButton()

        if #available(iOS 13.0, *) {
            view.setImage(UIImage(systemName: "pin"), for: .normal)
            view.tintColor = .systemBlue
        } else {
            view.setTitle(String.localized("pin"), for: .normal)
            view.setTitleColor(.systemBlue, for: .normal)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        view.imageView?.contentMode = .scaleAspectFit
        view.accessibilityLabel = String.localized("pin")
        return view
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

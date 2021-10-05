import UIKit
import InputBarAccessoryView
import DcCore

public protocol ChatSearchDelegate: class {
    func onSearchPreviousPressed()
    func onSearchNextPressed()
}

public class ChatSearchAccessoryBar: UIView, InputItem {
    public var inputBarAccessoryView: InputBarAccessoryView?
    public var parentStackViewPosition: InputStackView.Position?
    public func textViewDidChangeAction(with textView: InputTextView) {}
    public func keyboardSwipeGestureAction(with gesture: UISwipeGestureRecognizer) {}
    public func keyboardEditingEndsAction() {}
    public func keyboardEditingBeginsAction() {}

    public var isEnabled: Bool {
        willSet(newValue) {
            upButton.isEnabled = newValue
            downButton.isEnabled = newValue
        }
    }

    weak var delegate: ChatSearchDelegate?

    private lazy var upButton: UIButton = {
        let view = UIButton()

        if #available(iOS 13.0, *) {
            view.setImage(UIImage(systemName: "chevron.up"), for: .normal)
            view.tintColor = .systemBlue
        } else {
            view.setTitle(String.localized("previous"), for: .normal)
            view.setTitleColor(.systemBlue, for: .normal)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        view.imageView?.contentMode = .scaleAspectFit
        return view
    }()

    private lazy var downButton: UIButton = {
        let view = UIButton()
        view.tintColor = .systemBlue
        if #available(iOS 13.0, *) {
            view.setImage(UIImage(systemName: "chevron.down"), for: .normal)
            view.tintColor = .systemBlue
        } else {
            view.setTitle(String.localized("next"), for: .normal)
            view.setTitleColor(.systemBlue, for: .normal)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.imageView?.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        return view
    }()

    private lazy var searchResultLabel: UILabel = {
        let view = UILabel(frame: .zero)
        view.font = UIFont.preferredFont(for: .body, weight: .regular)
        view.textColor = DcColors.grayDateColor
        view.textAlignment = .center
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var buttonContainer: UIStackView = {
        let view = UIStackView(arrangedSubviews: [downButton, upButton])
        view.axis = .horizontal
        view.distribution = .equalSpacing
        view.alignment = .trailing
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    convenience init() {
        self.init(frame: .zero)

    }

    public override init(frame: CGRect) {
        isEnabled = false
        super.init(frame: frame)
        self.setupSubviews()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setupSubviews() {
        addSubview(searchResultLabel)
        addSubview(buttonContainer)

        addConstraints([
            searchResultLabel.constraintCenterYTo(self),
            searchResultLabel.constraintCenterXTo(self),
            buttonContainer.constraintAlignTopTo(self, paddingTop: 4),
            buttonContainer.constraintAlignBottomTo(self, paddingBottom: 4),
            buttonContainer.constraintWidthTo(80),
            buttonContainer.constraintAlignTrailingToAnchor(self.safeAreaLayoutGuide.trailingAnchor, paddingTrailing: 22),
            upButton.constraintHeightTo(36),
            downButton.constraintHeightTo(36),
        ])

        backgroundColor = DcColors.chatBackgroundColor

        let upGestaureListener = UITapGestureRecognizer(target: self, action: #selector(onUpPressed))
        upButton.addGestureRecognizer(upGestaureListener)

        let downGestureListener = UITapGestureRecognizer(target: self, action: #selector(onDownPressed))
        downButton.addGestureRecognizer(downGestureListener)
    }

    @objc func onUpPressed() {
        delegate?.onSearchPreviousPressed()
    }

    @objc func onDownPressed() {
        delegate?.onSearchNextPressed()
    }

    public func updateSearchResult(sum: Int, position: Int) {
        if sum == 0 {
            searchResultLabel.text = nil
        } else {
            searchResultLabel.text = "\(position) / \(sum)"
        }
    }
}

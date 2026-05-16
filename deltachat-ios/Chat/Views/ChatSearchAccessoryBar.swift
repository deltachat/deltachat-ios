import UIKit
import DcCore

public protocol ChatSearchDelegate: AnyObject {
    func onSearchPreviousPressed()
    func onSearchNextPressed()
}

public class ChatSearchToolBar: UIView {
    public var isEnabled: Bool {
        willSet(newValue) {
            upButton.isEnabled = newValue
            downButton.isEnabled = newValue
        }
    }

    weak var delegate: ChatSearchDelegate?

    private lazy var upButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "chevron.up"),
            style: .plain,
            target: self,
            action: #selector(onUpPressed)
        )
        // TODO: Accessibility title
        return button
    }()

    private lazy var downButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "chevron.down"),
            style: .plain,
            target: self,
            action: #selector(onDownPressed)
        )
        // TODO: Accessibility title
        return button
    }()

    private lazy var searchResultLabel: UIBarButtonItem = {
        let item = UIBarButtonItem()
        item.isEnabled = false
        if #available(iOS 26.0, *) {
            item.tintColor = DcColors.defaultTextColor
        } else {
            item.tintColor = DcColors.grayTextColor
        }
        return item
    }()

    private lazy var toolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.items = [searchResultLabel, .flexibleSpace(), upButton, downButton]
        return toolbar
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
        addSubview(toolbar)
        toolbar.fillSuperviewAvoidingSafeAreaAndKeyboard()
    }

    @objc func onUpPressed() {
        delegate?.onSearchPreviousPressed()
    }

    @objc func onDownPressed() {
        delegate?.onSearchNextPressed()
    }

    public func updateSearchResult(sum: Int, position: Int) {
        if #available(iOS 26.0, *) {
            // On liquid glass you can see button items with no text so we remove it.
            // Note that UIBarButtonItem.isHidden does nothing on iOS 26.
            if sum == 0 {
                toolbar.items = [.flexibleSpace(), upButton, downButton]
            } else {
                toolbar.items = [searchResultLabel, .flexibleSpace(), upButton, downButton]
            }
        }

        if sum == 0 {
            searchResultLabel.title = nil
        } else {
            searchResultLabel.title = "\(position) / \(sum)"
        }
    }
}

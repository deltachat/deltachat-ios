import UIKit
import DcCore

class ChatViewController2: UIViewController {

    var dcContext: DcContext
    let chatId: Int
    var messageIds: [Int] = []

    var heightConstraint: NSLayoutConstraint?
    var bottomInset: CGFloat {
        get {
            logger.debug("bottomInset - get: \(heightConstraint?.constant ?? 0)")
            return heightConstraint?.constant ?? 0
        }
        set {
            logger.debug("bottomInset - set: \(newValue)")
            heightConstraint?.constant = newValue
        }
    }


    lazy var isGroupChat: Bool = {
        return dcContext.getChat(chatId: chatId).isGroup
    }()

    lazy var draft: DraftModel = {
        let draft = DraftModel(dcContext: dcContext, chatId: chatId)
        return draft
    }()

    lazy var tableView: UITableView = {
        let tableView: UITableView = UITableView(frame: .zero)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()

    lazy var textView: ChatInputTextView = {
        let textView = ChatInputTextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = DcColors.inputFieldColor
        textView.isEditable = true
        textView.delegate = self
        return textView
    }()

    lazy var dummyView: UIView = {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .yellow
        view.addSubview(textView)
        return view
    }()

    private lazy var keyboardManager: KeyboardManager? = {
        let manager = KeyboardManager()
        return manager
    }()

    public lazy var backgroundContainer: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.backgroundColor = .blue
        if let backgroundImageName = UserDefaults.standard.string(forKey: Constants.Keys.backgroundImageName) {
            view.sd_setImage(with: Utils.getBackgroundImageURL(name: backgroundImageName),
                             placeholderImage: nil,
                             options: [.retryFailed]) { [weak self] (_, error, _, _) in
                if let error = error {
                    logger.error("Error loading background image: \(error.localizedDescription)" )
                    DispatchQueue.main.async { [weak self] in
                        self?.setDefaultBackgroundImage(view: view)
                    }
                }
            }
        } else {
             setDefaultBackgroundImage(view: view)
        }
        return view
    }()

    init(dcContext: DcContext, chatId: Int, highlightedMsg: Int? = nil) {
        self.dcContext = dcContext
        self.chatId = chatId
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
        tableView.backgroundView = backgroundContainer
        tableView.register(TextMessageCell.self, forCellReuseIdentifier: "text")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        navigationController?.setNavigationBarHidden(false, animated: false)

        if #available(iOS 13.0, *) {
            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        }

        navigationItem.backButtonTitle = String.localized("chat")
        definesPresentationContext = true

        if !dcContext.isConfigured() {
            // TODO: display message about nothing being configured
            return
        }

        // Binding to the tableView will enable interactive dismissal
        keyboardManager?.bind(to: tableView)
        keyboardManager?.on(event: .willChangeFrame) { [weak self] event in
            guard let self = self else { return }
            if self.keyboardManager?.isKeyboardHidden ?? true {
                return
            }
            logger.debug("willChangeFrame \(event)")
            let keyboardScreenEndFrame = event.endFrame
            self.bottomInset = self.getInputTextHeight() + self.dummyView.convert(keyboardScreenEndFrame, from: self.view.window).height
        }.on(event: .willHide) { [weak self] event in
            guard let self = self else { return }
            logger.debug("willHide \(event)")
            self.bottomInset = self.getInputTextHeight()
        }.on(event: .didHide) { [weak self] event in
            guard let self = self else { return }
            logger.debug("didHide \(event)")
            self.bottomInset = self.getInputTextHeight()
        }.on(event: .willShow) { [weak self] event in
            guard let self = self else { return }
            logger.debug("willShow \(event)")
            self.bottomInset = self.getInputTextHeight() + self.dummyView.convert(event.endFrame, from: self.view.window).height
            UIView.animate(withDuration: event.timeInterval, delay: 0, options: event.animationOptions, animations: {
                self.dummyView.layoutIfNeeded()
            })
        }

        loadMessages()
    }

    private func getInputTextHeight() -> CGFloat {
        var bottomHeight: CGFloat = 0
        if let keyboardManager = keyboardManager,
            keyboardManager.isKeyboardDisappearing || keyboardManager.isKeyboardHidden {
            bottomHeight = Utils.getSafeBottomLayoutInset()
        }
        return bottomHeight + textView.intrinsicContentSize.height
    }

    private func loadMessages() {
        // update message ids
        var msgIds = dcContext.getChatMsgs(chatId: chatId)
        let freshMsgsCount = self.dcContext.getUnreadMessages(chatId: self.chatId)
        if freshMsgsCount > 0 && msgIds.count >= freshMsgsCount {
            let index = msgIds.count - freshMsgsCount
            msgIds.insert(Int(DC_MSG_ID_MARKER1), at: index)
        }
        self.messageIds = msgIds
        self.reloadData()
    }

    private func reloadData() {
        let selectredRows = tableView.indexPathsForSelectedRows
        tableView.reloadData()
        // There's an iOS bug, filling up the console output but which can be ignored: https://developer.apple.com/forums/thread/668295
        // [Assert] Attempted to call -cellForRowAtIndexPath: on the table view while it was in the process of updating its visible cells, which is not allowed.
        selectredRows?.forEach({ (selectedRow) in
            tableView.selectRow(at: selectedRow, animated: false, scrollPosition: .none)
        })
    }

    func setupSubviews() {
        view.addSubview(tableView)
        view.addSubview(dummyView)
        view.addConstraints([
            tableView.constraintAlignTopToAnchor(view.topAnchor),
            tableView.constraintAlignLeadingToAnchor(view.leadingAnchor),
            tableView.constraintAlignTrailingToAnchor(view.trailingAnchor),
            tableView.constraintAlignBottomToAnchor(dummyView.topAnchor),
            dummyView.constraintAlignLeadingToAnchor(view.leadingAnchor),
            dummyView.constraintAlignTrailingToAnchor(view.trailingAnchor),
            dummyView.constraintAlignBottomToAnchor(view.bottomAnchor),
            textView.constraintAlignTopTo(dummyView),
            textView.constraintAlignLeadingTo(dummyView),
            textView.constraintAlignTrailingTo(dummyView),
            textView.constraintAlignBottomTo(dummyView),
        ])
        heightConstraint = dummyView.constraintMinHeightTo(bottomInset)
        bottomInset = getInputTextHeight()
        heightConstraint?.isActive = true

        navigationItem.title = "new Chat UI"

    }

    private func configureUIForWriting() {
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.dragInteractionEnabled = true
    }

    private func setDefaultBackgroundImage(view: UIImageView) {
        if #available(iOS 12.0, *) {
            view.image = UIImage(named: traitCollection.userInterfaceStyle == .light ? "background_light" : "background_dark")
        } else {
            view.image = UIImage(named: "background_light")
        }
    }
}

extension ChatViewController2: UITableViewDelegate {

}

extension ChatViewController2: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messageIds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }
}

// MARK: - UITextViewDelegate
extension ChatViewController2: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        self.bottomInset = self.getInputTextHeight() + (self.keyboardManager?.keyboardHeight ?? 0)
    }
}

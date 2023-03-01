import UIKit
import DcCore

class ChatViewController2: UIViewController {

    var dcContext: DcContext
    let chatId: Int
    var messageIds: [Int] = []

    var heightConstraint: NSLayoutConstraint?
    var bottomPaddingConstraint: NSLayoutConstraint?
    var bottomInset: CGFloat {
        get {
            logger.debug("bottomInset - get: \(heightConstraint?.constant ?? 0)")
            return heightConstraint?.constant ?? 0
        }
        set {
            logger.debug("bottomInset - set: \(newValue)")
            heightConstraint?.constant = newValue
            bottomPaddingConstraint?.constant = newValue
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

    /// The `InputBarAccessoryView` used as the `inputAccessoryView` in the view controller.
    lazy var messageInputBar: InputBarAccessoryView = {
        let inputBar = InputBarAccessoryView()
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        return inputBar
    }()

    lazy var dummyView: UIView = {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .yellow
        view.addSubview(messageInputBar)
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
        return bottomHeight + messageInputBar.intrinsicContentSize.height
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
            messageInputBar.constraintAlignTopTo(dummyView),
            messageInputBar.constraintAlignLeadingTo(dummyView),
            messageInputBar.constraintAlignTrailingTo(dummyView),
        ])
        heightConstraint = dummyView.constraintMinHeightTo(bottomInset)
        bottomPaddingConstraint = messageInputBar.constraintAlignBottomTo(dummyView, paddingBottom: 0)
        bottomInset = getInputTextHeight()
        bottomPaddingConstraint?.isActive = true
        heightConstraint?.isActive = true
        navigationItem.title = "new Chat UI"
        configureMessageInputBar()

    }

    private func configureUIForWriting() {
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.dragInteractionEnabled = true
    }

    private func configureMessageInputBar() {
        //messageInputBar.delegate = self
        messageInputBar.inputTextView.tintColor = DcColors.primary
        messageInputBar.inputTextView.placeholder = String.localized("chat_input_placeholder")
        messageInputBar.inputTextView.accessibilityLabel = String.localized("write_message_desktop")
        messageInputBar.separatorLine.backgroundColor = DcColors.colorDisabled
        messageInputBar.inputTextView.tintColor = DcColors.primary
        messageInputBar.inputTextView.textColor = DcColors.defaultTextColor
        messageInputBar.inputTextView.backgroundColor = DcColors.inputFieldColor
        messageInputBar.inputTextView.placeholderTextColor = DcColors.placeholderColor
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 38)
        messageInputBar.inputTextView.placeholderLabelInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 38)
        messageInputBar.inputTextView.layer.borderColor = DcColors.colorDisabled.cgColor
        messageInputBar.inputTextView.layer.borderWidth = 1.0
        messageInputBar.inputTextView.layer.cornerRadius = 13.0
        messageInputBar.inputTextView.layer.masksToBounds = true
        messageInputBar.inputTextView.scrollIndicatorInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        configureInputBarItems()
        messageInputBar.inputTextView.delegate = self
        messageInputBar.sendButton.isEnabled = true
       // messageInputBar.inputTextView.imagePasteDelegate = self
       // messageInputBar.onScrollDownButtonPressed = scrollToBottom
       // messageInputBar.ll.setDropInteractionDelegate(delegate: self)
    }

    private func configureInputBarItems() {

        messageInputBar.setLeftStackViewWidthConstant(to: 40, animated: false)
        messageInputBar.setRightStackViewWidthConstant(to: 40, animated: false)


        let sendButtonImage = UIImage(named: "paper_plane")?.withRenderingMode(.alwaysTemplate)
        messageInputBar.sendButton.image = sendButtonImage
        messageInputBar.sendButton.accessibilityLabel = String.localized("menu_send")
        messageInputBar.sendButton.accessibilityTraits = .button
        messageInputBar.sendButton.title = nil
        messageInputBar.sendButton.tintColor = UIColor(white: 1, alpha: 1)
        messageInputBar.sendButton.layer.cornerRadius = 20
        messageInputBar.middleContentViewPadding = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        // this adds a padding between textinputfield and send button
        messageInputBar.sendButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        messageInputBar.sendButton.setSize(CGSize(width: 40, height: 40), animated: false)
        messageInputBar.padding = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 12)
        messageInputBar.shouldManageSendButtonEnabledState = false

        let leftItems = [
            InputBarButtonItem()
                .configure {
                    $0.spacing = .fixed(0)
                    let clipperIcon = #imageLiteral(resourceName: "ic_attach_file_36pt").withRenderingMode(.alwaysTemplate)
                    $0.image = clipperIcon
                    $0.tintColor = DcColors.primary
                    $0.setSize(CGSize(width: 40, height: 40), animated: false)
                    $0.accessibilityLabel = String.localized("menu_add_attachment")
                    $0.accessibilityTraits = .button
            }.onSelected {
                $0.tintColor = UIColor.themeColor(light: .lightGray, dark: .darkGray)
            }.onDeselected {
                $0.tintColor = DcColors.primary
            }.onTouchUpInside { [weak self] _ in
               // self?.clipperButtonPressed()
            }
        ]

        messageInputBar.setStackViewItems(leftItems, forStack: .left, animated: false)

        // This just adds some more flare
        messageInputBar.sendButton
            .onEnabled { item in
                UIView.animate(withDuration: 0.3, animations: {
                    item.backgroundColor = DcColors.primary
                })}
            .onDisabled { item in
                UIView.animate(withDuration: 0.3, animations: {
                    item.backgroundColor = DcColors.colorDisabled
                })}
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
        self.messageInputBar.invalidateIntrinsicContentSize()
        self.bottomInset = self.getInputTextHeight() + (self.keyboardManager?.keyboardHeight ?? 0)
    }
}

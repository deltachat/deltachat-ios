import UIKit
import DcCore

protocol SendingControllerDelegate: AnyObject {
    func onSendingAttemptFinished()
}

class SendingController: UIViewController {

    private let dcMsgs: [DcMsg]
    private let chatId: Int
    private let dcContext: DcContext
    weak var delegate: SendingControllerDelegate?

    private var progressLabel: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.text = String.localized("one_moment")
        return view
    }()
    
    private lazy var initialsBadge: InitialsBadge = {
        let view = InitialsBadge(size: 95)
        let chat = dcContext.getChat(chatId: chatId)
        view.setColor(chat.color)
        if let image = chat.profileImage {
            view.setImage(image)
        } else {
            view.setName(chat.name)
        }
        view.isHidden = true
        return view
    }()

    private var activityIndicator: UIActivityIndicatorView = {
        let view: UIActivityIndicatorView
        if #available(iOS 13, *) {
             view = UIActivityIndicatorView(style: .large)
        } else {
            view = UIActivityIndicatorView(style: .whiteLarge)
            view.color = UIColor.gray
        }
        view.startAnimating()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    init(chatId: Int, dcMsgs: [DcMsg], dcContext: DcContext) {
        self.chatId = chatId
        self.dcMsgs = dcMsgs
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    override func viewDidLoad() {
        view.backgroundColor = DcColors.defaultBackgroundColor
        setupViews()
        sendMessage()
    }

    private func setupViews() {
        view.addSubview(progressLabel)
        view.addSubview(activityIndicator)
        view.addSubview(initialsBadge)
        view.addConstraints([
            progressLabel.constraintCenterXTo(view),
            progressLabel.constraintAlignTopTo(view, paddingTop: 25),
            activityIndicator.constraintCenterXTo(view),
            activityIndicator.constraintCenterYTo(view),
            initialsBadge.constraintCenterXTo(view),
            initialsBadge.constraintCenterYTo(view)
        ])
        setupNavigationBar()
    }

    private func setupNavigationBar() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem()
        self.navigationItem.titleView = UIImageView(image: UIImage(named: "ic_chat")?.scaleDownImage(toMax: 26))
    }

    private func sendMessage() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            for dcMsg in self.dcMsgs {
                self.dcContext.sendMsgSync(chatId: self.chatId, msg: dcMsg)
            }

            if !self.dcContext.getChat(chatId: self.chatId).isSelfTalk {
                self.initialsBadge.isHidden = false
                let image = self.initialsBadge.asImage()
                self.initialsBadge.isHidden = true
                DcUtils.donateSendMessageIntent(context: self.dcContext, chatId: self.chatId, chatAvatar: image)
            }
            self.delegate?.onSendingAttemptFinished()
        }
    }
}

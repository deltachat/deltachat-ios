import UIKit
import DcCore
import SwiftUI

class MessageInfoViewController: UIViewController {
    var dcContext: DcContext
    var message: DcMsg
    let receipts: [(contact: DcContact, timestamp: Double)]

    init(dcContext: DcContext, message: DcMsg) {
        self.dcContext = dcContext
        self.message = message
        self.receipts = dcContext.getMessageReadReceipts(messageId: message.id).map {
            (dcContext.getContact(id: Int($0)), $1)
        }.sorted { $0.timestamp > $1.timestamp }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("menu_message_details")

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(dismiss(_:)))
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: .ellipsisNavigation()), menu: UIMenu(children: [
            UIAction(title: String.localized("global_menu_view_developer_desktop")) { [unowned self] _ in
                show(MessageDeveloperInfoViewController(dcContext: dcContext, message: message), sender: nil)
            }
        ]))

        let host = UIHostingController(rootView: rootView)
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        host.view.fillSuperview()
    }

    @objc private func dismiss(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }

    var rootView: some View {
        List {
            if message.isFromCurrentSender {
                HStack {
                    Text(String.localized("message_detail_sent_desktop")).bold()
                    Spacer()
                    Text(DateUtils.getExtendedAbsTimeSpanString(timeStamp: Double(message.timestamp)))
                }
            } else {
                HStack {
                    Text(String.localized("message_detail_received_desktop")).bold()
                    Spacer()
                    Text(DateUtils.getExtendedAbsTimeSpanString(timeStamp: message.receivedTimestamp))
                }
            }
            if !receipts.isEmpty {
                Section(content: {
                    ForEach(receipts, id: \.contact.id) { (contact, timestamp) in
                        HStack {
                            InitialsBadgeRepresentable(size: 40, contact: contact)
                                .frame(width: 40, height: 40)
                            Text(contact.displayName).bold()
                            Spacer()
                            Text(DateUtils.getExtendedAbsTimeSpanString(timeStamp: timestamp))
                        }
                    }
                }, header: {
                    HStack {
                        Text(String.localized("read_by"))
                        Spacer()
                        Image("ic_done_all_36pt")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 20)
                    }
                })
            }
        }
    }
}

class MessageDeveloperInfoViewController: UIViewController {
    var dcContext: DcContext
    var message: DcMsg

    init(dcContext: DcContext, message: DcMsg) {
        self.dcContext = dcContext
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("menu_message_details")

        let textView = UITextView(frame: view.frame)
        textView.text = dcContext.getMsgInfo(msgId: message.id)
        textView.isEditable = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textContainerInset = .init(top: 20, left: 20, bottom: 20, right: 20)
        view.addSubview(textView)
        textView.fillSuperview()
    }
}

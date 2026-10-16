import UIKit
import DcCore
import SwiftUI

class MessageInfoViewController: UIViewController {
    var dcContext: DcContext
    var message: DcMsg
    var receipts: [(contact: DcContact, timestamp: Double)]

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

        let host = UIHostingController(rootView: rootView)
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        host.view.fillSuperview()
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
                        Text("Read by")
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

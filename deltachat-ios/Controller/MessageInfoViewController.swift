import UIKit
import DcCore
import SwiftUI

class MessageInfoViewController: UIViewController {
    var dcContext: DcContext
    var message: DcMsg
    private static let reuseIdentifier = "MessageInfoCell"

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

        let host = UIHostingController(rootView: rootView)
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        host.view.fillSuperview()
    }

    var rootView: some View {
        List {
            Section("Read by") {
                HStack {
                    Image(systemName: "person.fill")
                        .clipShape(Circle())
                    Text("Amzd")
                    Spacer()
                    Text(DateUtils.getExtendedAbsTimeSpanString(timeStamp: Date(timeIntervalSinceNow: -3000).timeIntervalSince1970))
                }
            }
        }
    }
}

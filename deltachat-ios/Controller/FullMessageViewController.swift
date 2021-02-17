import UIKit
import WebKit
import DcCore

class FullMessageViewController: WebViewViewController {

    var message: DcMsg
    private var loadUrlAllowed = false

    // Block just everything :)
    let blockRules = """
    [
        {
            "trigger": {
                "url-filter": ".*"
            },
            "action": {
                "type": "block"
            }
        }
    ]
    """
    

    init(message: DcMsg) {
        self.message = message
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = String.localized("chat_input_placeholder")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "ContentBlockingRules",
                encodedContentRuleList: blockRules) { (contentRuleList, error) in

            guard let contentRuleList = contentRuleList, error == nil else {
                return
            }

            let configuration = self.webView.configuration
            configuration.userContentController.add(contentRuleList)
            self.loadHtml()

        }
    }

    private func loadHtml() {
        // execute in background thread because file loading would blockui for a few milliseconds
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let html = self.message.html
            DispatchQueue.main.async {
                self.webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }
}

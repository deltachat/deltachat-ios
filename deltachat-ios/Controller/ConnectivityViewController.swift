import UIKit
import DcCore

class ConnectivityViewController: WebViewViewController {
    let dcContext: DcContext

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = String.localized("connectivity")
        loadHtml()
    }

    private func loadHtml() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let html = self.dcContext.getConnectivityHtml()
            DispatchQueue.main.async {
                self.webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }
}

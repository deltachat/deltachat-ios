import UIKit
import WebKit
import DcCore

class HelpViewController: WebViewViewController {

    override init() {
        super.init()
        self.allowSearch = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = String.localized("menu_help")
        self.webView.isOpaque = false
        self.webView.backgroundColor = .clear
        view.backgroundColor = DcColors.defaultBackgroundColor
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadHtmlContent { [weak self] url in
            // return to main thread
            DispatchQueue.main.async {
                self?.webView.loadFileURL(url, allowingReadAccessTo: url)
            }
        }
    }

    private func loadHtmlContent(completionHandler: ((URL) -> Void)?) {
        // execute in background thread because file loading would blockui for a few milliseconds
        DispatchQueue.global(qos: .userInitiated).async {
            let langAndRegion = Locale.preferredLanguages.first ?? "en"
            let langOnly = String(langAndRegion.split(separator: "-").first ?? Substring("ErrLang"))
            var fileURL: URL?

            fileURL = Bundle.main.url(forResource: "help", withExtension: "html", subdirectory: "Assets/Help/\(langAndRegion)") ??
                Bundle.main.url(forResource: "help", withExtension: "html", subdirectory: "Assets/Help/\(langOnly)") ??
                Bundle.main.url(forResource: "help", withExtension: "html", subdirectory: "Assets/Help/en")

            guard let url = fileURL else {
                safe_fatalError("could not find help asset")
                return
            }
            completionHandler?(url)
        }
    }
}

import UIKit
import WebKit

protocol AppPickerViewControllerDelegate: AnyObject {
    func pickedAnDownloadedApp(_ viewController: AppPickerViewController, fileURL: URL)
}

class AppPickerViewController: UIViewController {
    // Web view
    // Context
    weak var delegate: AppPickerViewControllerDelegate?
    let webView: WKWebView

    init(url: URL = URL(string: "https://webxdc.org/apps/")!) {
        webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.load(URLRequest(url: url))

        super.init(nibName: nil, bundle: nil)

        webView.navigationDelegate = self
        view.addSubview(webView)
        view.backgroundColor = .systemGroupedBackground
        setupConstraints()

        title = String.localized("webxdc_apps")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: webView.bottomAnchor),
        ]

        NSLayoutConstraint.activate(constraints)
    }
}

extension AppPickerViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            return decisionHandler(.cancel)
        }

        // if url ends with .xdc -> download and store in core and call delegate
        if url.pathExtension == "xdc" {
            // TODO: Add loading indicator
            Task {
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let filepath = FileHelper.saveData(data: data, name: url.lastPathComponent)
                else { return decisionHandler(.cancel) }

                let fileURL = NSURL(fileURLWithPath: filepath)
                delegate?.pickedAnDownloadedApp(self, fileURL: fileURL as URL)
                decisionHandler(.cancel)
            }
        } else if url.host == "webxdc.org" {
            decisionHandler(.allow)
        } else if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.cancel)
        }
    }
}

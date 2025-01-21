import UIKit
import WebKit

protocol WebxdcStoreViewControllerDelegate: AnyObject {
    func downloadStarted(_ viewController: WebxdcStoreViewController)
    func downloadEnded(_ viewController: WebxdcStoreViewController)
    func pickedAnDownloadedApp(_ viewController: WebxdcStoreViewController, fileURL: URL)
}

class WebxdcStoreViewController: UIViewController {
    weak var delegate: WebxdcStoreViewControllerDelegate?
    let webView: WKWebView

    init(url: URL = URL(string: "https://webxdc.org/apps/")!) {
        webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.load(URLRequest(url: url))

        super.init(nibName: nil, bundle: nil)

        webView.navigationDelegate = self
        view.addSubview(webView)
        view.backgroundColor = .systemBackground
        setupConstraints()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: webView.bottomAnchor),
        ]

        NSLayoutConstraint.activate(constraints)
    }
}

extension WebxdcStoreViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            return decisionHandler(.cancel)
        }

        // if url ends with .xdc -> download and store in core and call delegate
        if url.pathExtension == "xdc" {
            Task { [weak self] in
                guard let self else { return }
                // show spinner instead of close-button
                delegate?.downloadStarted(self)

                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let filepath = FileHelper.saveData(data: data, name: url.lastPathComponent)
                else {
                    delegate?.downloadEnded(self)
                    return decisionHandler(.cancel)
                }

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

class DownloadingView: UIView {
    let activityIndicator: UIActivityIndicatorView
    private let blurView: UIVisualEffectView

    init() {
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .label
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 10
        blurView.layer.masksToBounds = true

        super.init(frame: .zero)

        addSubview(blurView)
        addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),

            activityIndicator.topAnchor.constraint(equalTo: blurView.topAnchor, constant: 20),
            activityIndicator.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 20),
            blurView.trailingAnchor.constraint(equalTo: activityIndicator.trailingAnchor, constant: 20),
            blurView.bottomAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

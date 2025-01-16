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
    var defaultCloseButton: UIBarButtonItem?
    let downloadingView: DownloadingView

    init(url: URL = URL(string: "https://webxdc.org/apps/")!) {
        webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.load(URLRequest(url: url))

        downloadingView = DownloadingView()
        downloadingView.translatesAutoresizingMaskIntoConstraints = false
        downloadingView.isHidden = true

        super.init(nibName: nil, bundle: nil)

        webView.navigationDelegate = self
        view.addSubview(webView)
        view.addSubview(downloadingView)
        view.backgroundColor = .systemBackground
        setupConstraints()
        let closeButton = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(AppPickerViewController.close(_:)))

        title = String.localized("webxdc_apps")
        navigationItem.leftBarButtonItem = closeButton
        self.defaultCloseButton = closeButton
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: webView.bottomAnchor),

            downloadingView.topAnchor.constraint(equalTo: view.topAnchor),
            downloadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: downloadingView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: downloadingView.bottomAnchor),
        ]

        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Actions

    @objc func close(_ sender: Any) {
        dismiss(animated: true)
    }

    @objc func showLoading() {
        title = String.localized("Downloading...")
        downloadingView.isHidden = false
        downloadingView.activityIndicator.startAnimating()
        downloadingView.activityIndicator.hidesWhenStopped = true
        navigationItem.leftBarButtonItem = nil
    }

    @objc func hideLoading() {
        title = String.localized("webxdc_apps")
        downloadingView.isHidden = true
        downloadingView.activityIndicator.stopAnimating()
        navigationItem.leftBarButtonItem = defaultCloseButton
    }
}

extension AppPickerViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            return decisionHandler(.cancel)
        }

        // if url ends with .xdc -> download and store in core and call delegate
        if url.pathExtension == "xdc" {
            Task { [weak self] in
                guard let self else { return }
                // show spinner instead of close-button
                await MainActor.run {
                    self.showLoading()
                }
                
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let filepath = FileHelper.saveData(data: data, name: url.lastPathComponent)
                else {
                    await MainActor.run {
                        self.hideLoading()
                    }
                    return decisionHandler(.cancel)
                }

                if #available(iOS 16.0, *) {
                    try await Task.sleep(for: .seconds(2))
                }

                let fileURL = NSURL(fileURLWithPath: filepath)
                delegate?.pickedAnDownloadedApp(self, fileURL: fileURL as URL)
                await MainActor.run {
                    self.dismiss(animated: true)
                }

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
        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        blurView.translatesAutoresizingMaskIntoConstraints = false

        super.init(frame: .zero)

        addSubview(blurView)
        addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),

            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(equalTo: blurView.trailingAnchor),
            bottomAnchor.constraint(equalTo: blurView.bottomAnchor),
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

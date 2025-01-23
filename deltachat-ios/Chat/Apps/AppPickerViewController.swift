import UIKit

protocol AppPickerViewControllerDelegate: AnyObject {
    func pickedAnDownloadedApp(_ viewController: AppPickerViewController, fileURL: URL)
}

/// Container ViewController for WebxdcStoreViewController and RecentWebxdcAppsViewController
class AppPickerViewController: UIViewController {
    var defaultCloseButton: UIBarButtonItem?
    let downloadingView: DownloadingView

    // add segmented control to title view
    let storeViewController: WebxdcStoreViewController
    weak var delegate: AppPickerViewControllerDelegate?

    init() {
        storeViewController = WebxdcStoreViewController()

        downloadingView = DownloadingView()
        downloadingView.translatesAutoresizingMaskIntoConstraints = false
        downloadingView.isHidden = true

        super.init(nibName: nil, bundle: nil)

        storeViewController.delegate = self
        let closeButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel, target: self, action: #selector(AppPickerViewController.close(_:)))

        addChild(storeViewController)
        view.addSubview(storeViewController.view)
        storeViewController.didMove(toParent: self)
        view.addSubview(downloadingView)

        title = String.localized("webxdc_apps")
        navigationItem.leftBarButtonItem = closeButton
        self.defaultCloseButton = closeButton

        setupConstraints()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            downloadingView.topAnchor.constraint(equalTo: view.topAnchor),
            downloadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: downloadingView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: downloadingView.bottomAnchor),
        ]

        NSLayoutConstraint.activate(constraints)
    }

    @objc func close(_ sender: Any) {
        dismiss(animated: true)
    }


    // MARK: - Actions

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


extension AppPickerViewController: WebxdcStoreViewControllerDelegate {
    func downloadStarted(_ viewController: WebxdcStoreViewController) {
        DispatchQueue.main.async { [weak self] in
            self?.showLoading()
        }
    }
    
    func downloadEnded(_ viewController: WebxdcStoreViewController) {
        DispatchQueue.main.async { [weak self] in
            self?.hideLoading()
        }
    }
    
    func pickedAnDownloadedApp(_ viewController: WebxdcStoreViewController, fileURL: URL) {
        delegate?.pickedAnDownloadedApp(self, fileURL: fileURL)
        dismiss(animated: true)
    }
}

import UIKit
import DcCore

protocol AppPickerViewControllerDelegate: AnyObject {
    func pickedApp(_ viewController: AppPickerViewController, fileURL: URL)
}

/// Container ViewController for WebxdcStoreViewController and RecentWebxdcAppsViewController
class AppPickerViewController: UIViewController {
    var defaultCloseButton: UIBarButtonItem?
    let downloadingView: DownloadingView

    // TODO: let segmentedControl: UISegmentedControl
    private let pageViewController: UIPageViewController
    let storeViewController: WebxdcStoreViewController
    let myAppsViewController: RecentWebxdcAppsViewController
    weak var delegate: AppPickerViewControllerDelegate?

    init(context: DcContext) {
        storeViewController = WebxdcStoreViewController()
        myAppsViewController = RecentWebxdcAppsViewController(context: context)
        pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pageViewController.setViewControllers([storeViewController], direction: .forward, animated: false)

        downloadingView = DownloadingView()
        downloadingView.translatesAutoresizingMaskIntoConstraints = false
        downloadingView.isHidden = true

        super.init(nibName: nil, bundle: nil)

        storeViewController.delegate = self
        myAppsViewController.delegate = self
        let closeButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel, target: self, action: #selector(AppPickerViewController.close(_:)))

        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)
        view.addSubview(downloadingView)
        pageViewController.dataSource = self
        view.backgroundColor = .systemBackground

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
        delegate?.pickedApp(self, fileURL: fileURL)
        dismiss(animated: true)
    }
}

extension AppPickerViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if viewController == myAppsViewController {
            return storeViewController
        } else {
            return nil
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if viewController == storeViewController {
            return myAppsViewController
        } else {
            return nil
        }
    }
}

extension AppPickerViewController: WebxdcSelectorDelegate {
    func onWebxdcFromFilesSelected(url: URL) {
        // we need do duplicate/copy the file to `caches` due to ... core-reasons
        guard let data = try? Data(contentsOf: url),
              let path = FileHelper.saveData(data: data,
                                             name: UUID().uuidString,
                                             suffix: "xdc",
                                             directory: .cachesDirectory),
              let duplicateUrl = URL(string: path)
        else { return }

        delegate?.pickedApp(self, fileURL: duplicateUrl)
        dismiss(animated: true)
    }
}

import UIKit
import DcCore

protocol AppPickerViewControllerDelegate: AnyObject {
    func pickedApp(_ viewController: AppPickerViewController, fileURL: URL)
}


/// Container ViewController for WebxdcStoreViewController and RecentWebxdcAppsViewController
class AppPickerViewController: UIViewController {

    enum Tab: Int, CaseIterable {
        case store = 0
        case myApps = 1

        var title: String {
            switch self {
            case .myApps:
                String.localized("emoji_recent")
            case .store:
                String.localized("browse")
            }
        }
    }

    var defaultCloseButton: UIBarButtonItem?
    let downloadingView: DownloadingView

    let segmentedControl: UISegmentedControl
    private let pageViewController: UIPageViewController
    let storeViewController: WebxdcStoreViewController
    let myAppsViewController: RecentWebxdcAppsViewController
    weak var delegate: AppPickerViewControllerDelegate?

    init(context: DcContext) {
        storeViewController = WebxdcStoreViewController()
        myAppsViewController = RecentWebxdcAppsViewController(context: context)
        pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pageViewController.setViewControllers([storeViewController], direction: .forward, animated: false)

        segmentedControl = UISegmentedControl(items: Tab.allCases.map { $0.title })
        segmentedControl.selectedSegmentIndex = Tab.store.rawValue

        downloadingView = DownloadingView()
        downloadingView.translatesAutoresizingMaskIntoConstraints = false
        downloadingView.isHidden = true

        super.init(nibName: nil, bundle: nil)

        storeViewController.delegate = self
        myAppsViewController.delegate = self

        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)
        view.addSubview(downloadingView)
        view.backgroundColor = .systemBackground

        segmentedControl.addTarget(self, action: #selector(AppPickerViewController.segmentedControlValueChanged(_:)), for: .valueChanged)
        navigationItem.titleView = segmentedControl

        let closeButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.close, target: self, action: #selector(AppPickerViewController.close(_:)))
        navigationItem.rightBarButtonItem = closeButton
        self.defaultCloseButton = closeButton

        setupConstraints()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            downloadingView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
        navigationController?.isModalInPresentation = true
        title = String.localized("downloading")
        navigationItem.titleView = nil
        downloadingView.isHidden = false
        downloadingView.activityIndicator.startAnimating()
        downloadingView.activityIndicator.hidesWhenStopped = true
        navigationItem.rightBarButtonItem = nil
    }

    @objc func hideLoading() {
        navigationController?.isModalInPresentation = false
        navigationItem.titleView = segmentedControl
        downloadingView.isHidden = true
        downloadingView.activityIndicator.stopAnimating()
        navigationItem.rightBarButtonItem = defaultCloseButton
    }

    @objc func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        guard let tab = Tab(rawValue: sender.selectedSegmentIndex) else { return }

        switch tab {
        case .store:
            pageViewController.setViewControllers([storeViewController], direction: .reverse, animated: true)
        case .myApps:
            pageViewController.setViewControllers([myAppsViewController], direction: .forward, animated: true)
        }
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

extension AppPickerViewController: RecentWebxdcAppsViewControllerDelegate {
    func webxdcFileSelected(_ viewController: RecentWebxdcAppsViewController, url: URL) {
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

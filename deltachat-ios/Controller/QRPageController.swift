import UIKit

class QRPageController: UIPageViewController {

    var selectedIndex: Int = 0

    private lazy var qrSegmentControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Show Left", "Show Right"])
        control.tintColor = DcColors.primary
        control.addTarget(self, action: #selector(qrSegmentControlChanged), for: .valueChanged)
        return control
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
        view.makeBorder()
        dataSource = self
    }

    private func setupSubviews() {
        view.addSubview(qrSegmentControl)
        qrSegmentControl.translatesAutoresizingMaskIntoConstraints = false
        qrSegmentControl.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
        qrSegmentControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 15).isActive = true
    }

    // MARK: - actions
    @objc private func qrSegmentControlChanged(_ sender: UISegmentedControl) {

    }
}

extension QRPageController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        return UIViewController()
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        return UIViewController()
    }


}


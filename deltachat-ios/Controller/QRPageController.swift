import UIKit
import DcCore

class QRPageController: UIPageViewController {

    private let dcContext: DcContext

    var selectedIndex: Int = 0

    private lazy var qrController: QrViewController = {
        let controller = QrViewController(dcContext: dcContext)
        return controller
    }()

    private lazy var qrCameraController: UIViewController = {
        let vc = UIViewController()
        vc.view.backgroundColor = .green
        return vc
    }()

    private lazy var qrSegmentControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Show Left", "Show Right"])
        control.tintColor = DcColors.primary
        control.addTarget(self, action: #selector(qrSegmentControlChanged), for: .valueChanged)
        return control
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: [:])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        delegate = self
        navigationItem.titleView = qrSegmentControl
        setViewControllers(
            [qrController],
            direction: .forward,
            animated: true,
            completion: nil
        )
    }

    // MARK: - actions
    @objc private func qrSegmentControlChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            setViewControllers([qrController], direction: .reverse, animated: true, completion: nil)
        } else {
            setViewControllers([qrCameraController], direction: .forward, animated: true, completion: nil)
        }
    }
}

// MARK: - UIPageViewControllerDataSource, UIPageViewControllerDelegate
extension QRPageController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if viewController is QrViewController {
            return nil
        }
        return qrController
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if viewController is QrViewController {
            return qrCameraController
        }
        return nil
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            if previousViewControllers.first is QrViewController {
                qrSegmentControl.selectedSegmentIndex = 1
            } else {
                qrSegmentControl.selectedSegmentIndex = 0
            }
        }
    }
}

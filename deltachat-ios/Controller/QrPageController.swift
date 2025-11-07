import UIKit
import DcCore

class QrPageController: UIPageViewController {
    private let dcContext: DcContext
    private let dcAccounts: DcAccounts
    var progressObserver: NSObjectProtocol?
    let qrCodeReaderController: QrCodeReaderController
    let qrViewController: QrViewController

    private var selectedIndex: Int = 0

    private var qrCodeHint: String {
        return String.localizedStringWithFormat(String.localized("qrshow_join_contact_hint"), dcContext.displayname ?? dcContext.addr ?? "")
    }

    private lazy var qrSegmentControl: UISegmentedControl = {
        let control = UISegmentedControl(
            items: [String.localized("qrshow_title"), String.localized("qrscan_title")]
        )
        control.tintColor = DcColors.primary
        control.addTarget(self, action: #selector(qrSegmentControlChanged), for: .valueChanged)
        control.selectedSegmentIndex = 0
        return control
    }()

    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()

        qrViewController = QrViewController(dcContext: dcContext)
        qrCodeReaderController = QrCodeReaderController(title: String.localized("qrscan_title"))
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: [:])

        qrCodeReaderController.delegate = self
        qrViewController.qrCodeHint = self.qrCodeHint
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
        updateMenuItems()

        setViewControllers(
            [qrViewController],
            direction: .forward,
            animated: true,
            completion: nil
        )

        navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHintTextIfNeeded()    // needed in case user changes profile name
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.progressObserver = nil
    }

    // MARK: - actions
    @objc private func qrSegmentControlChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            setViewControllers([qrViewController], direction: .reverse, animated: true, completion: nil)
        } else {
            setViewControllers([qrCodeReaderController], direction: .forward, animated: true, completion: nil)
        }
        updateMenuItems()
    }

    private func updateMenuItems() {
        let menu = moreButtonMenu()
        let button =  UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
        navigationItem.rightBarButtonItem = button
    }

    private func moreButtonMenu() -> UIMenu {
        var actions = [UIMenuElement]()
        if qrSegmentControl.selectedSegmentIndex == 0 {
            actions.append(UIAction(title: String.localized("menu_share"), image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.share()
            })
            actions.append(UIAction(title: String.localized("menu_copy_to_clipboard"), image: UIImage(systemName: "document.on.document")) { [weak self] _ in
                self?.copyToClipboard()
            })
        }
        actions.append(UIAction(title: String.localized("paste_from_clipboard"), image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in
            self?.pasteFromClipboard()
        })
        if dcContext.isChatmail == false {
            actions.append(UIAction(title: String.localized("menu_new_classic_contact"), image: UIImage(systemName: "highlighter")) { [weak self] _ in
                guard let self else { return }
                self.navigationController?.pushViewController(NewContactController(dcContext: self.dcContext), animated: true)
            })
        }
        if qrSegmentControl.selectedSegmentIndex == 0 {
            actions.append(UIAction(title: String.localized("withdraw_qr_code"), image: UIImage(systemName: "trash"), attributes: [.destructive]) { [weak self] _ in
                self?.withdrawQrCode()
            })
        }
        return UIMenu(children: actions)
    }

    func share() {
        if let inviteLink = Utils.getInviteLink(context: dcContext, chatId: 0) {
            if let sourceItem = navigationItem.rightBarButtonItem {
                Utils.share(url: inviteLink, parentViewController: self, sourceItem: sourceItem)
            }
        }
    }

    func copyToClipboard() {
        UIPasteboard.general.string = Utils.getInviteLink(context: dcContext, chatId: 0)
    }

    func withdrawQrCode() {
        let alert = UIAlertController(title: String.localized("withdraw_verifycontact_explain"), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: String.localized("withdraw_qr_code"), style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            guard let code = dcContext.getSecurejoinQr(chatId: 0) else { return }
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            _ = self.dcContext.setConfigFromQR(qrCode: code)
            setViewControllers([QrViewController(dcContext: dcContext, qrCodeHint: qrCodeHint)], direction: .reverse, animated: false, completion: nil)
            appDelegate.appCoordinator.presentTabBarController()
        }))
        present(alert, animated: true)
    }

    func pasteFromClipboard() {
        handleQrCode(UIPasteboard.general.string ?? "")
    }

    // MARK: - update
    private func updateHintTextIfNeeded() {
        let newHint = qrCodeHint
        if newHint != qrViewController.qrCodeHint {
            qrViewController.qrCodeHint = newHint
        }
    }

}

// MARK: - UIPageViewControllerDataSource, UIPageViewControllerDelegate
extension QrPageController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if viewController is QrViewController {
            return nil
        } else {
            return qrViewController
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if viewController is QrViewController {
            return qrCodeReaderController
        } else {
            return nil
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        if pendingViewControllers.first is QrViewController {
            qrSegmentControl.selectedSegmentIndex = 0
        } else {
            qrSegmentControl.selectedSegmentIndex = 1
        }
        updateMenuItems()
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if !completed {
            if previousViewControllers.first is QrViewController {
                qrSegmentControl.selectedSegmentIndex = 0
            } else {
                qrSegmentControl.selectedSegmentIndex = 1
            }
            updateMenuItems()
        }
    }
}

// MARK: - QRCodeDelegate
extension QrPageController: QrCodeReaderDelegate {
    func handleQrCode(_ qrCode: String) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.appCoordinator.coordinate(qrCode: qrCode, from: self)
    }
}

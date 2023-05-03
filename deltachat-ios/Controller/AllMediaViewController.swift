import UIKit
import DcCore

class AllMediaViewController: UIPageViewController {

    private struct Page {
        let headerTitle: String
        let type1: Int32
        let type2: Int32
        let type3: Int32
    }

    private let dcContext: DcContext
    private let chatId: Int
    private var prevIndex: Int = 0

    private func getPages() -> [Page] {
        let webxdcReallyInUse = dcContext.getChatMedia(chatId: chatId, messageType: DC_MSG_WEBXDC, messageType2: 0, messageType3: 0).count
                                    >= (chatId == 0 ? 5 : 1)
        pages.append(Page(
            headerTitle: String.localized("files"),
            type1: DC_MSG_FILE, type2: webxdcReallyInUse ? 0 : DC_MSG_WEBXDC, type3: 0
        ))
        if webxdcReallyInUse {
            pages.append(Page(
                headerTitle: String.localized("webxdc_apps"),
                type1: DC_MSG_WEBXDC, type2: 0, type3: 0
            ))
        }
        pages.append(Page(
            headerTitle: String.localized("audio"),
            type1: DC_MSG_AUDIO, type2: DC_MSG_VOICE, type3: 0
        ))
        pages.append(Page(
            headerTitle: String.localized("gallery"),
            type1: DC_MSG_IMAGE, type2: DC_MSG_GIF, type3: DC_MSG_VIDEO
        ))
        return pages
    }
    private var pages: [Page] = []

    private lazy var segmentControl: UISegmentedControl = {
        let control = UISegmentedControl(items: pages.map({$0.headerTitle}))
        control.tintColor = DcColors.primary
        control.addTarget(self, action: #selector(segmentControlChanged), for: .valueChanged)
        control.selectedSegmentIndex = 0
        return control
    }()

    init(dcContext: DcContext, chatId: Int = 0) {
        self.dcContext = dcContext
        self.chatId = chatId
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: [:])
        self.pages = self.getPages()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        delegate = self
        navigationItem.titleView = segmentControl


        setViewControllers(
            [makeViewController(pages[0])],
            direction: .forward,
            animated: true,
            completion: nil
        )

        if #available(iOS 13, *) {
            self.navigationController?.navigationBar.scrollEdgeAppearance = self.navigationController?.navigationBar.standardAppearance
        }
    }

    // MARK: - actions
    @objc private func segmentControlChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex < pages.count {
            let page = pages[sender.selectedSegmentIndex]
            setViewControllers([makeViewController(page)],
                               direction: sender.selectedSegmentIndex > prevIndex ? .forward : .reverse, animated: true, completion: nil)
            prevIndex = sender.selectedSegmentIndex
        }
    }

    // MARK: - factory
    private func makeViewController(_ page: Page) -> UIViewController {
        if page.type1 == DC_MSG_IMAGE {
            let allMedia = dcContext.getChatMedia(chatId: chatId, messageType: page.type1, messageType2: page.type2, messageType3: page.type3)
            return GalleryViewController(context: dcContext, chatId: chatId, mediaMessageIds: allMedia.reversed())
        } else {
            return FilesViewController(context: dcContext, chatId: chatId, type1: page.type1, type2: page.type2, type3: page.type3)
        }
    }
}

// MARK: - UIPageViewControllerDataSource, UIPageViewControllerDelegate
extension AllMediaViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func getIndexFromObject(_ viewController: UIViewController) -> Int {
        let type1: Int32
        if let filesViewContoller = viewController as? FilesViewController {
            type1 = filesViewContoller.type1
        } else {
            type1 = DC_MSG_IMAGE
        }
        for (index, page) in pages.enumerated() {
            if page.type1 == type1 {
                return index
            }
        }
        return 0
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        let i = getIndexFromObject(viewController)
        if i > 0 {
            return makeViewController(pages[i - 1])
        }
        return nil
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        let i = getIndexFromObject(viewController)
        if i < (pages.count - 1) {
            return makeViewController(pages[i + 1])
        }
        return nil
    }

    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        if let viewController = pendingViewControllers.first {
            let i = getIndexFromObject(viewController)
            segmentControl.selectedSegmentIndex = i
            prevIndex = i
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if let viewController = previousViewControllers.first, !completed {
            let i = getIndexFromObject(viewController)
            segmentControl.selectedSegmentIndex = i
            prevIndex = i
        }
    }
}

import QuickLook
import UIKit

class PreviewController: QLPreviewController {

    private var urls: [URL]

    private lazy var doneButtonItem: UIBarButtonItem = {
        let button = UIBarButtonItem(title: String.localized("done"), style: .done, target: self, action: #selector(doneButtonPressed(_:)))
        return button
    }()

    private let bottomToolbarIdentifier = "QLCustomToolBarModalAccessibilityIdentifier" // QLCustomToolBarAccessibilityIdentifier
    private let listButtonIdentifier = "QLOverlayListButtonAccessibilityIdentifier"
    private let shareButtonIdentifier = "QLOverlayDefaultActionButtonAccessibilityIdentifier"

    // hack to hide list button for iOS 13.4 and lower
    private var fakeToolbarTop: NSLayoutConstraint?
    private var fakeToolbarBottom: NSLayoutConstraint?
    private var fakeToolbarLeading: NSLayoutConstraint?
    private var fakeToolbarTrailing: NSLayoutConstraint?
    private var nativeToolbar: NativeToolbar?

    private var observerToken: NSKeyValueObservation?

    // this toolbar will cover the default toolbar
      private lazy var fakeToolbar: UIToolbar = {
          let toolbar = UIToolbar()
          let shareItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareButtonTapped(_:)))
          toolbar.backgroundColor = .clear
          toolbar.items = [shareItem]
          return toolbar
      }()

    init(currentIndex: Int, urls: [URL]) {
        self.urls = urls
        super.init(nibName: nil, bundle: nil)
        dataSource = self
        currentPreviewItemIndex = currentIndex
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if navigationController?.isBeingPresented ?? false {
            /*
             QLPreviewController comes with a done-button by default. But if is embedded in UINavigationContrller we need to set a done-button manually.
            */
            navigationItem.leftBarButtonItem = doneButtonItem
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // native toolbar is accessable just on and after viewWillAppear
        hideListButtonInNavigationBarIfNeeded()
        if #available(iOS 13.5, *) {
            hideListButtonInBottomToolBarIfNeeded()
        } else {
            setupFakeToolbarIfNeeded()
        }
    }

    private func findListButton(view: UIView) -> UIView? {
        if view.accessibilityIdentifier == listButtonIdentifier {
            return view
        }
        return view.subviews.compactMap { findListButton(view: $0) }.first
    }

    // MARK: - actions
    @objc private func doneButtonPressed(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension PreviewController: QLPreviewControllerDataSource {

    func numberOfPreviewItems(in _: QLPreviewController) -> Int {
        return urls.count
    }

    func previewController(_: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return urls[index] as QLPreviewItem
    }
}

// MARK: - customisation (to hide list button)
private extension PreviewController {

    func hideListButtonInBottomToolBarIfNeeded() {
        let bottomToolbar = getQLBottomToolbar(root: self.view)
        if let toolbar = bottomToolbar {
            let listButton = toolbar.items?.filter { $0.accessibilityIdentifier == listButtonIdentifier }.first
            listButton?.tintColor = .clear
            listButton?.action = nil
        }
    }

    func hideListButtonInNavigationBarIfNeeded() {
        guard let navBar = getQLNavigationBar(rootView: view) else {
            return
        }
        if let items = navBar.items, let item = items.first {
           let leftItems = item.leftBarButtonItems
            let listButton = leftItems?.filter { $0.accessibilityIdentifier == listButtonIdentifier }.first
            // listButton is impossible to remove so we make it invisible
            listButton?.isEnabled = false
            listButton?.tintColor = .clear
        }
    }

    func getQLBottomToolbar(root: UIView) -> UIToolbar? {

        if let toolbar = root as? UIToolbar, toolbar.accessibilityIdentifier == bottomToolbarIdentifier {
            return toolbar
        }
        return root.subviews.compactMap {
            getQLBottomToolbar(root: $0)
        }.first
    }

    func getQLNavigationBar(rootView: UIView) -> UINavigationBar? {
        for subview in rootView.subviews {
            if subview is UINavigationBar {
                return subview as? UINavigationBar
            } else {
                if let navigationBar = self.getQLNavigationBar(rootView: subview) {
                    return navigationBar
                }
            }
        }
        return nil
    }
}

private extension PreviewController {

    struct NativeToolbar {
        let qlToolbar: UIToolbar
        let qlShareButton: UIBarButtonItem?
    }

    var fakeToolBarLayoutSetup: Bool {
        return fakeToolbarTop != nil && fakeToolbarBottom != nil && fakeToolbarLeading != nil && fakeToolbarTrailing != nil
    }

    private func setupFakeToolbarIfNeeded() {

        if fakeToolBarLayoutSetup {
            return
        }

        guard let qlToolbar = getQLBottomToolbar(root: self.view) else {
            return
        }

        var shareButton: UIBarButtonItem?
        for item in qlToolbar.items ?? [] {
            if item.accessibilityIdentifier == shareButtonIdentifier {
               shareButton = item
            }
        }

        self.nativeToolbar = NativeToolbar(qlToolbar: qlToolbar, qlShareButton: shareButton)

        // this will bind native toolbar's alpha to our fake toolbar (used on swipe down events)
        _ = qlToolbar.observe(\.alpha, changeHandler: { [weak self] toolbar, _ in self?.fakeToolbar.alpha = toolbar.alpha})

        view.addSubview(fakeToolbar)
        fakeToolbar.translatesAutoresizingMaskIntoConstraints = false
        fakeToolbarLeading = fakeToolbar.leadingAnchor.constraint(equalTo: qlToolbar.leadingAnchor)
        fakeToolbarTop = fakeToolbar.topAnchor.constraint(equalTo: qlToolbar.topAnchor)
        fakeToolbarTrailing = fakeToolbar.trailingAnchor.constraint(equalTo: qlToolbar.trailingAnchor)
        fakeToolbarBottom = fakeToolbar.bottomAnchor.constraint(equalTo: qlToolbar.bottomAnchor)

        fakeToolbarLeading?.isActive = true
        fakeToolbarTop?.isActive = true
        fakeToolbarTrailing?.isActive = true
        fakeToolbarBottom?.isActive = true
    }

    @objc private func shareButtonTapped(_ sender: UIBarButtonItem) {
         guard let defaultShareButton = self.nativeToolbar?.qlShareButton else { return }
         // trigger action of native qlShareButton
         _ = defaultShareButton.target?.perform(defaultShareButton.action, with: nil)
     }

}

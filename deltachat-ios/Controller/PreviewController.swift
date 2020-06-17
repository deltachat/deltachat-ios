import QuickLook
import UIKit

class PreviewController: QLPreviewController {

    struct QLBottomToolbar {
        let toolbar: UIToolbar
        let shareButton: UIBarButtonItem?
        let listButton: UIBarButtonItem?
    }

    private var urls: [URL]

    private lazy var doneButtonItem: UIBarButtonItem = {
        let button = UIBarButtonItem(title: String.localized("done"), style: .done, target: self, action: #selector(doneButtonPressed(_:)))
        return button
    }()

    // this toolbar will cover the default toolbar
    private lazy var customToolbar: UIToolbar = {
        let toolbar = UIToolbar()
        let shareItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareButtonTapped(_:)))
        toolbar.backgroundColor = .clear
        toolbar.items = [shareItem]
        return toolbar
    }()

    private var qlToolbarCopy: QLBottomToolbar? // object that holds references to native qlToolbar

    private let bottomToolbarIdentifier = "QLCustomToolBarModalAccessibilityIdentifier"
    private let shareIdentifier = "QLOverlayDefaultActionButtonAccessibilityIdentifier"
    private let listButtonIdentifier = "QLOverlayListButtonAccessibilityIdentifier"

    private var customToolbarLeadingConstraint: NSLayoutConstraint?
    private var customToolbarTrailingConstraint: NSLayoutConstraint?
    private var customToolbarTopConstraint: NSLayoutConstraint?
    private var customToolbarBottomConstraint: NSLayoutConstraint?

    private var customToolbarHasLayout: Bool {
        return customToolbarLeadingConstraint != nil
            && customToolbarTopConstraint != nil
            && customToolbarTrailingConstraint != nil
            && customToolbarBottomConstraint != nil
    }

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
            /* QLPreviewController comes with a done-button by default. But if is embedded in UINavigationContrller we need to set a done-button manually.
            */
            navigationItem.leftBarButtonItem = doneButtonItem
        }
        view.addSubview(customToolbar)
    }

    @objc private func shareButtonTapped(_ sender: UIBarButtonItem) {
        guard let defaultShareButton = self.qlToolbarCopy?.shareButton else { return }
        // trigger action of nativeShareButton
        _ = defaultShareButton.target?.perform(defaultShareButton.action, with: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // native toolbar is accessable just on and after viewWillAppear
        qlToolbarCopy = traverseSearchToolbar(root: self.view)
        layoutCustumToolbarIfNeeded()
        hideListButtonInNavigationBarIfNeeded()
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
    // MARK: - bottom bar customisation
    func traverseSearchToolbar(root: UIView) -> QLBottomToolbar? {

        if let toolbar = root as? UIToolbar {
            if toolbar.accessibilityIdentifier == bottomToolbarIdentifier {
                return extractBottomBar(toolbar: toolbar)
            }
        }
        if root.subviews.isEmpty {
            return nil
        }

        var subviews = root.subviews
        var current = subviews.popLast()
        while current != nil {
            if let current = current, let toolbar = traverseSearchToolbar(root: current) {
                return toolbar
            }
            current = subviews.popLast()
        }
        return nil
    }

    func layoutCustumToolbarIfNeeded() {
        guard let nativeToolbar = qlToolbarCopy?.toolbar else {
            return
        }
        if !customToolbarHasLayout {
            customToolbar.translatesAutoresizingMaskIntoConstraints = false
            customToolbarLeadingConstraint = customToolbar.leadingAnchor.constraint(equalTo: nativeToolbar.leadingAnchor, constant: 0)
            customToolbarTopConstraint = customToolbar.topAnchor.constraint(equalTo: nativeToolbar.topAnchor, constant: 0)
            customToolbarTrailingConstraint = customToolbar.trailingAnchor.constraint(equalTo: nativeToolbar.trailingAnchor, constant: 0)
            customToolbarBottomConstraint = customToolbar.bottomAnchor.constraint(equalTo: nativeToolbar.bottomAnchor, constant: 0)
            [
                customToolbarLeadingConstraint, customToolbarTopConstraint, customToolbarTrailingConstraint, customToolbarBottomConstraint
            ].forEach { $0?.isActive = true }
        }
    }

    func extractBottomBar(toolbar: UIToolbar) -> QLBottomToolbar? {
        // share item, flex item, list item
        var shareButton: UIBarButtonItem?
        var listButton: UIBarButtonItem?
        for item in toolbar.items ?? [] {
            if item.accessibilityIdentifier ==  shareIdentifier {
                shareButton = item
            } else if item.accessibilityIdentifier == listButtonIdentifier {
                listButton = item
            }
        }
        if listButton == nil {
            // if there is no list button we can leave the bar (ipads)
            return nil
        }
        return QLBottomToolbar(toolbar: toolbar, shareButton: shareButton, listButton: listButton)
    }

    // MARK: - navigation bar customization

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

}

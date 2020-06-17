import QuickLook
import UIKit

class PreviewController: QLPreviewController {

    struct QLToolbar {
        let toolbar: UIToolbar
        let shareButton: UIBarButtonItem?
        let listButton: UIBarButtonItem?
    }

    var urls: [URL]

    private lazy var doneButtonItem: UIBarButtonItem = {
        let button = UIBarButtonItem(title: String.localized("done"), style: .done, target: self, action: #selector(doneButtonPressed(_:)))
        return button
    }()

    // we use this toolbar to cover the default toolbar
    lazy var customToolbar: UIToolbar = {
        let toolbar = UIToolbar()
        let shareItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareButtonTapped(_:)))
        toolbar.items = [shareItem]
        return toolbar
    }()

    var qlToolbarCopy: QLToolbar? // object that holds references to native qlToolbar

    var customToolbarLeadingConstraint: NSLayoutConstraint?
    var customToolbarTrailingConstraint: NSLayoutConstraint?
    var customToolbarTopConstraint: NSLayoutConstraint?
    var customToolbarBottomConstraint: NSLayoutConstraint?

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

    private func layoutCustumToolbarIfNeeded() {
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // native toolbar is accessable just on and after viewWillAppear
        qlToolbarCopy = traverseSearchToolbar(root: self.view)
        layoutCustumToolbarIfNeeded()
        hideListButtonInNavigationBarIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        traverseSearchToolbar(root: self.view)
    }

    // MARK: - customisation
    private func traverseSearchToolbar(root: UIView) -> QLToolbar? {

        let toolbarIdentifier = "QLCustomToolBarModalAccessibilityIdentifier"
        let shareIdentifier = "QLOverlayDefaultActionButtonAccessibilityIdentifier"

        if let toolbar = root as? UIToolbar, let items = toolbar.items {
            if toolbar.accessibilityIdentifier == toolbarIdentifier {
                // share item, flex item, list item
                var shareButton: UIBarButtonItem?
                var listButton: UIBarButtonItem?
                for item in items {
                    if item.accessibilityIdentifier ==  shareIdentifier {
                        shareButton = item
                    } else if item.accessibilityIdentifier == "QLOverlayListButtonAccessibilityIdentifier" {
                        listButton = item
                    }
                }
                if listButton == nil {
                    // if there is no list button we can leave the bar (ipads)
                    return nil
                }

                return QLToolbar(toolbar: toolbar, shareButton: shareButton, listButton: listButton)
            } else {
                print(toolbar)
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

    private func hideListButtonInNavigationBarIfNeeded() {
        let items = navigationItem.leftBarButtonItems
        print(items)
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

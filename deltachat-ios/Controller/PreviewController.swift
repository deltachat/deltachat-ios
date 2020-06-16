import QuickLook
import UIKit

class PreviewController: QLPreviewController {

    var urls: [URL]

    // we use this toolbar to hide the default toolbar
    lazy var customToolbar: UIToolbar = {
        let toolbar = UIToolbar()
        let shareItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareButtonTapped(_:)))
        toolbar.items = [shareItem]
        return toolbar
    }()

    var qlToolbar: UIToolbar?               // the  native toolbar
    var qlShareButton: UIBarButtonItem?     // the native shareButton

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

    private lazy var doneButtonItem: UIBarButtonItem = {
        let button = UIBarButtonItem(title: String.localized("done"), style: .done, target: self, action: #selector(doneButtonPressed(_:)))
        return button
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
            /* QLPreviewController comes with a done-button by default. But if is embedded in UINavigationContrller we need to set a done-button manually.
            */
            navigationItem.leftBarButtonItem = doneButtonItem
        }
        view.addSubview(customToolbar)
    }

    @objc private func shareButtonTapped(_ sender: UIBarButtonItem) {
        guard let defaultShareButton = self.qlShareButton else { return }
        // execute action of nativeShareButton
        _ = defaultShareButton.target?.perform(defaultShareButton.action, with: nil)
    }

    private func layoutCustumToolbarIfNeeded() {
        guard let defaultToolbar = qlToolbar else {
            return
        }
        if !customToolbarHasLayout {
            customToolbar.translatesAutoresizingMaskIntoConstraints = false
            customToolbarLeadingConstraint = customToolbar.leadingAnchor.constraint(equalTo: defaultToolbar.leadingAnchor, constant: 0)
            customToolbarTopConstraint = customToolbar.topAnchor.constraint(equalTo: defaultToolbar.topAnchor, constant: 0)
            customToolbarTrailingConstraint = customToolbar.trailingAnchor.constraint(equalTo: defaultToolbar.trailingAnchor, constant: 0)
            customToolbarBottomConstraint = customToolbar.bottomAnchor.constraint(equalTo: defaultToolbar.bottomAnchor, constant: 0)
            [
                customToolbarLeadingConstraint, customToolbarTopConstraint, customToolbarTrailingConstraint, customToolbarBottomConstraint
            ].forEach { $0?.isActive = true }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // native toolbar is accessable after viewWillAppear
        qlToolbar = traverseSearchToolbar(root: self.view)
        layoutCustumToolbarIfNeeded()
    }

    private func traverseSearchToolbar(root: UIView) -> UIToolbar? {
        if let toolbar = root as? UIToolbar, let items = toolbar.items {
            if items.count == 3 {
                // share item, flex item, list item
                self.qlShareButton = items[0] // we need the share button to trigger share events
                return toolbar
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

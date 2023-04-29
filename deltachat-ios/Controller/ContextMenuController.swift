import AVKit
import AVFoundation
import SDWebImage
import DcCore


protocol ContextMenuItem {
    var msg: DcMsg { get set }
    var thumbnailImage: UIImage? { get set  }
}

// MARK: - ContextMenuController
class ContextMenuController: UIViewController {

    let item: ContextMenuItem

    var msg: DcMsg {
        return item.msg
    }

    init(item: ContextMenuItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        let viewType = msg.viewtype
        var thumbnailView: UIView?
        switch viewType {
        case .image:
            thumbnailView = makeImageView(image: msg.image)
        case .video:
            thumbnailView = makeVideoView(videoUrl: msg.fileURL)
        case .gif:
            thumbnailView = makeGifView(gifImage: item.thumbnailImage)
        default:
            return
        }

        guard let contentView = thumbnailView else {
            return
        }

        view.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentView.leftAnchor.constraint(equalTo: view.leftAnchor),
            contentView.rightAnchor.constraint(equalTo: view.rightAnchor),
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - thumbnailView creation
    private func makeGifView(gifImage: UIImage?) -> UIView? {
        let view = SDAnimatedImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = DcColors.defaultBackgroundColor
        if let image = gifImage {
            setPreferredContentSize(for: image)
        }
        view.image = gifImage
        return view
    }

    private func makeImageView(image: UIImage?) -> UIView? {
        guard let image = image else {
            return nil
        }

        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.image = image
        setPreferredContentSize(for: image)
        return imageView
    }

    private func makeVideoView(videoUrl: URL?) -> UIView? {
        guard let videoUrl = videoUrl, let videoSize = item.thumbnailImage?.size else { return nil }
        let player = AVPlayer(url: videoUrl)
        let playerController = AVPlayerViewController()
        addChild(playerController)
        view.addSubview(playerController.view)
        playerController.didMove(toParent: self)
        playerController.view.backgroundColor = .darkGray
        playerController.view.clipsToBounds = true
        playerController.player = player
        playerController.showsPlaybackControls = false
        player.play()

        // truncate edges on top/bottom or sides
        let resizedHeightFactor = view.frame.height / videoSize.height
        let resizedWidthFactor = view.frame.width / videoSize.width
        let effectiveResizeFactor = min(resizedWidthFactor, resizedHeightFactor)
        let maxHeight = videoSize.height * effectiveResizeFactor
        let maxWidth = videoSize.width * effectiveResizeFactor
        let size = CGSize(width: maxWidth, height: maxHeight)
        preferredContentSize = size

        return playerController.view
    }

    private func setPreferredContentSize(for image: UIImage) {
        let width = view.bounds.width
        let height = image.size.height * (width / image.size.width)
        self.preferredContentSize = CGSize(width: width, height: height)
    }
}

class ContextMenuProvider {

    var menu: [ContextMenuItem] = []

    init(menu: [ContextMenuItem] = []) {
        self.menu = menu
    }

    func setMenu(_ menu: [ContextMenuItem]) {
        self.menu = menu
    }

    // iOS 12- action menu
    var menuItems: [UIMenuItem] {
        return menu
            .filter({ $0.title != nil && $0.action != nil })
            .map({ return UIMenuItem(title: $0.title!, action: $0.action!) })
    }

    private func filter(_ filters: [(Array<ContextMenuItem>.Element) throws -> Bool]?, in items: [ContextMenuItem]) -> [ContextMenuItem] {
        guard let filters = filters else {
            return items
        }

        var items = items
        for filter in filters {
            do {
                items = try items.filter(filter)
            } catch {
                logger.warning("applied context menu item filter is invalid")
            }
        }
        return items
    }

    public func getMenuItems(filters: [(Array<ContextMenuItem>.Element) throws -> Bool]) -> [UIMenuItem] {
        return filter(filters, in: menu)
            .filter({ $0.title != nil && $0.action != nil })
            .map({ return UIMenuItem(title: $0.title!, action: $0.action!) })
    }

    // iOS13+ action menu
    @available(iOS 13, *)
    func actionProvider(title: String = "",
                        image: UIImage? = nil,
                        identifier: UIMenu.Identifier? = nil,
                        indexPath: IndexPath,
                        filters: [(Array<ContextMenuItem>.Element) throws -> Bool]? = nil) -> UIMenu {

        var children: [UIMenuElement] = []
        let menuItems = filter(filters, in: menu)
        for item in menuItems {
            // we only support 1 submenu layer for now
            if var subMenus = item.children {
                subMenus = filter(filters, in: subMenus)
                var submenuChildren: [UIMenuElement] = []
                for submenuItem in subMenus {
                    submenuChildren.append(generateUIAction(item: submenuItem, indexPath: indexPath))
                }
                let submenu = UIMenu(title: "", options: .displayInline, children: submenuChildren)
                children.append(submenu)
            } else {
                children.append(generateUIAction(item: item, indexPath: indexPath))
            }
        }

        return UIMenu(
            title: title,
            image: image,
            identifier: identifier,
            children: children
        )
    }

    @available(iOS 13, *)
    private func generateUIAction(item: ContextMenuItem, indexPath: IndexPath) -> UIAction {
        let image = UIImage(systemName: item.imageName ?? "") ??
            UIImage(named: item.imageName ?? "")

        let action = UIAction(
            title: item.title ?? "",
            image: image,
            handler: { _ in item.onPerform?(indexPath) }
        )
        if item.isDestructive ?? false {
            action.attributes = [.destructive]
        }

        return action
    }

    func canPerformAction(action: Selector) -> Bool {
        return !menu.filter {
            $0.action == action
        }.isEmpty
    }

    func performAction(action: Selector, indexPath: IndexPath) {
        menu.filter {
            $0.action == action
        }.first?.onPerform?(indexPath)
    }

}

extension ContextMenuProvider {
    struct ContextMenuItem {
        var title: String?
        var imageName: String?
        let isDestructive: Bool?
        var action: Selector?
        var onPerform: ((IndexPath) -> Void)?
        var children: [ContextMenuItem]?

        init(title: String, imageName: String, isDestructive: Bool = false, action: Selector, onPerform: ((IndexPath) -> Void)?) {
            self.title = title
            self.imageName = imageName
            self.isDestructive = isDestructive
            self.action = action
            self.onPerform = onPerform
        }

        init(submenuitems: [ContextMenuItem]) {
            title = nil
            imageName = nil
            isDestructive = nil
            action = nil
            onPerform = nil
            children = submenuitems
        }
    }
}

import UIKit

class ContextMenuProvider {

    let menu: [ContextMenuItem]

    init(menu: [ContextMenuItem] = []) {
        self.menu = menu
    }

    // iOS 12- action menu
    var menuItems: [UIMenuItem] {
        return menu
            .filter({ $0.title != nil && $0.action != nil })
            .map({ return UIMenuItem(title: $0.title!, action: $0.action!) })
    }

    private func filter(_ filters: [(ContextMenuItem) throws -> Bool]?, in items: [ContextMenuItem]) -> [ContextMenuItem] {
        guard let filters else { return items }

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

// MARK: - iOS13+ action menu
@available(iOS 13, *)
extension ContextMenuProvider {
    func actionProvider(title: String = "",
                        image: UIImage? = nil,
                        identifier: UIMenu.Identifier? = nil,
                        indexPath: IndexPath,
                        filters: [(ContextMenuItem) throws -> Bool]? = []) -> UIMenu? {
        
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
                let image: UIImage?

                if let imageName = item.imageName {
                    image = UIImage(systemName: imageName)
                } else {
                    image = nil
                }

                let submenu = UIMenu(title: item.title ?? "", image: image, options: [], children: submenuChildren)
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
}

extension ContextMenuProvider {
    struct ContextMenuItem {
        var title: String?
        var imageName: String?
        let isDestructive: Bool?
        var action: Selector?
        var onPerform: ((IndexPath) -> Void)?
        var children: [ContextMenuItem]?

        init(title: String? = nil, imageName: String? = nil, isDestructive: Bool = false, action: Selector? = nil, children: [ContextMenuItem]? = nil, onPerform: ((IndexPath) -> Void)? = nil) {
            self.title = title
            self.imageName = imageName
            self.isDestructive = isDestructive
            self.action = action
            self.onPerform = onPerform
            self.children = children
        }
    }
}

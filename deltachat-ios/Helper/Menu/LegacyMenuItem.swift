import UIKit

class LegacyMenuItem: UIMenuItem {
    var indexPath: IndexPath?

    convenience init(title: String, action: Selector, indexPath: IndexPath?) {
        self.init(title: title, action: action)

        self.indexPath = indexPath
    }
}


@available(iOS 13.0, *)
extension UIAction {
    static func menuAction(localizationKey: String, attributes: UIAction.Attributes = [], systemImageName: String, indexPath: IndexPath, action: @escaping (IndexPath) -> Void) -> UIAction {
        return menuAction(localizationKey: localizationKey, attributes: attributes, image: UIImage(systemName: systemImageName), indexPath: indexPath, action: action)
    }

    static func menuAction(localizationKey: String, attributes: UIAction.Attributes = [], image: UIImage?, indexPath: IndexPath, action: @escaping (IndexPath) -> Void) -> UIAction {
        return UIAction(
            title: String.localized(localizationKey),
            image: image,
            attributes: attributes,
            handler: { _ in
                DispatchQueue.main.async {
                    action(indexPath)
                }
            }
        )
    }
}

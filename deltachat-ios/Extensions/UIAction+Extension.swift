import UIKit

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

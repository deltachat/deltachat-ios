import UIKit

extension UIAction {
    static func menuAction<T>(localizationKey: String, attributes: UIAction.Attributes = [], systemImageName: String, with arg: T, action: @escaping (T) -> Void) -> UIAction {
        return menuAction(localizationKey: localizationKey, attributes: attributes, image: UIImage(systemName: systemImageName), with: arg, action: action)
    }

    static func menuAction<T>(localizationKey: String, attributes: UIAction.Attributes = [], image: UIImage?, with arg: T, action: @escaping (T) -> Void) -> UIAction {
        return UIAction(
            title: String.localized(localizationKey),
            image: image,
            attributes: attributes,
            handler: { _ in
                DispatchQueue.main.async {
                    action(arg)
                }
            }
        )
    }
}

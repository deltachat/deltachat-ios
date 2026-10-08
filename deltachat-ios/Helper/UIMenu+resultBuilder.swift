import UIKit

@resultBuilder
public struct MenuElementBuilder {
    public static func buildBlock(_ components: UIMenuElement...) -> UIMenuElement {
        UIDeferredMenuElement({ $0(components) })
    }

    public static func buildArray(_ components: [UIMenuElement]) -> UIMenuElement {
        UIDeferredMenuElement({ $0(components) })
    }

    public static func buildOptional(_ component: UIMenuElement?) -> UIMenuElement {
        component ?? UIDeferredMenuElement({ $0([]) })
    }

    public static func buildEither(first component: UIMenuElement) -> UIMenuElement {
        component
    }

    public static func buildEither(second component: UIMenuElement) -> UIMenuElement {
        component
    }

    public static func buildPartialBlock(first: UIMenuElement) -> UIMenuElement {
        first
    }

    public static func buildPartialBlock(accumulated: UIMenuElement, next: UIMenuElement) -> UIMenuElement {
        UIDeferredMenuElement({ $0([accumulated, next]) })
    }
}

extension UIMenu {
    convenience init(title: String = "", image: UIImage? = nil, identifier: UIMenu.Identifier? = nil, options: Options = [], elementSize size: BackportedElementSize? = nil, @MenuElementBuilder uncached elements: @escaping () -> UIMenuElement) {
        let children = [UIDeferredMenuElement.uncached({ $0([elements()]) })]
        self.init(title: title, image: image, identifier: identifier, options: options, children: children)
        if #available(iOS 16.0, *), let size, let size = ElementSize(rawValue: size.rawValue) {
            preferredElementSize = size
        }
    }

    /// This only has an effect on iOS 16+
    enum BackportedElementSize: Int {
        case small = 0
        case medium = 1
        case large = 2
    }
}

import UIKit

/// A view that hides its content to a user's recording, broadcast or screenshot.
/// https://gist.github.com/Amzd/2652bc98a6ae098701b342d710e45aa7
@available(iOS 12, *)
@dynamicMemberLookup
class PrivacySensitiveView<ContentView: UIView>: UIView {
    private var content: ContentView
    private var textField = {
        let textField = UITextField()
        textField.isSecureTextEntry = true
        textField.isUserInteractionEnabled = false
        textField.backgroundColor = .clear
        return textField
    }()

    /// Setting this property to `false` enables the user’s ability to record and broadcast the content in the view again.
    /// Default is `true`.
    public var isPrivacySensitive: Bool {
        get { textField.isSecureTextEntry }
        set {
            textField.isSecureTextEntry = newValue
            setNeedsLayout()
        }
    }

    public init(content: ContentView) {
        self.content = content
        super.init(frame: content.frame)
        let container = textField.secureContainer ?? {
            assertionFailure("failed to get secureContainer")
            return UIView()
        }()
        addSubview(container)
        container.fillSuperview()
        container.addSubview(content)
        content.fillSuperview()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        content.hitTest(point, with: event)
    }

    subscript<T>(dynamicMember member: KeyPath<ContentView, T>) -> T {
        content[keyPath: member]
    }
    subscript<T>(dynamicMember member: WritableKeyPath<ContentView, T>) -> T {
        get { content[keyPath: member] }
        set { content[keyPath: member] = newValue }
    }
}

extension UITextField {
    @available(iOS 12, *)
    fileprivate var secureContainer: UIView? {
        let containerString = hiddenContainerTypeStringRepresentation
        return subviews.first { subview in
            type(of: subview).description() == containerString
        }
    }

    @available(iOS 12, *)
    private var hiddenContainerTypeStringRepresentation: String {
        if #available(iOS 15, *) {
            return "_UITextLayoutCanvasView"
        } else if #available(iOS 14, *) {
            return "_UITextFieldCanvasView"
        } else if #available(iOS 13, *) {
            return "_UITextFieldCanvasView"
        } else /*if #available(iOS 12, *)*/ {
            return "_UITextFieldContentView"
        }
    }
}

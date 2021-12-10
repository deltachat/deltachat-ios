import UIKit
import DcCore
import InputBarAccessoryView

public class DraftArea: UIView, InputItem {
    public var inputBarAccessoryView: InputBarAccessoryView?
    public var parentStackViewPosition: InputStackView.Position?
    public func textViewDidChangeAction(with textView: InputTextView) {}
    public func keyboardSwipeGestureAction(with gesture: UISwipeGestureRecognizer) {}
    public func keyboardEditingEndsAction() {}
    public func keyboardEditingBeginsAction() {}

    var delegate: DraftPreviewDelegate? {
        get {
            return quotePreview.delegate
        }
        set {
            quotePreview.delegate = newValue
            mediaPreview.delegate = newValue
            documentPreview.delegate = newValue
        }
    }

    lazy var mainContentView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [quotePreview, mediaPreview, documentPreview])
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        return view
    }()


    lazy var quotePreview: QuotePreview = {
        let view = QuotePreview()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var mediaPreview: MediaPreview = {
        let view = MediaPreview()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var documentPreview: DocumentPreview = {
        let view = DocumentPreview()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    convenience init() {
        self.init(frame: .zero)

    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupSubviews()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setupSubviews() {
        addSubview(mainContentView)
        backgroundColor = DcColors.defaultTransparentBackgroundColor
        mainContentView.fillSuperview()
    }

    public func configure(draft: DraftModel) {
        guard let  chatInputBar = inputBarAccessoryView as? ChatInputBar else {
            safe_fatalError("Expecting inputBarAccessoryView of type ChatInputBar")
            return
        }
        quotePreview.configure(draft: draft)
        mediaPreview.configure(draft: draft)
        documentPreview.configure(draft: draft)
        chatInputBar.configure(draft: draft)
    }

    /// reload cleans caches containing the drafted attachment so that the UI will update correctly
    public func reload(draft: DraftModel) {
        mediaPreview.reload(draft: draft)
        // TODO: add document reloading when document editing was added
    }

    public func cancel() {
        quotePreview.cancel()
        mediaPreview.cancel()
        documentPreview.cancel()
        if let chatInputBar = inputBarAccessoryView as? ChatInputBar {
            chatInputBar.cancel()
        }
    }

}

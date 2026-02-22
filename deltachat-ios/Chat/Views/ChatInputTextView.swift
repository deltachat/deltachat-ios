import Foundation
import UIKit
import MobileCoreServices

public class ChatInputTextView: InputTextView {

    enum MaterialBackgroundMode {
        case none
        case liquid(tintColor: UIColor?, interactive: Bool)
        case blur(UIBlurEffect.Style)
    }

    public weak var imagePasteDelegate: ChatInputTextViewPasteDelegate?

    private lazy var materialBackgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.isHidden = true
        view.clipsToBounds = true
        return view
    }()

    private lazy var materialEffectView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: nil)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true
        return view
    }()

    private lazy var dropInteraction: ChatDropInteraction = {
        return ChatDropInteraction()
    }()

    open override func setup() {
        super.setup()
        setupMaterialBackground()
    }

    private func setupMaterialBackground() {
        insertSubview(materialBackgroundView, at: 0)
        pinMaterialBackgroundToViewport()
        materialBackgroundView.addSubview(materialEffectView)
        materialEffectView.fillSuperview()
    }

    private func pinMaterialBackgroundToViewport() {
        NSLayoutConstraint.activate([
            materialBackgroundView.leadingAnchor.constraint(equalTo: frameLayoutGuide.leadingAnchor),
            materialBackgroundView.trailingAnchor.constraint(equalTo: frameLayoutGuide.trailingAnchor),
            materialBackgroundView.topAnchor.constraint(equalTo: frameLayoutGuide.topAnchor),
            materialBackgroundView.bottomAnchor.constraint(equalTo: frameLayoutGuide.bottomAnchor)
        ])
    }

    func applyMaterialBackground(mode: MaterialBackgroundMode) {
        switch mode {
        case .none:
            materialEffectView.effect = nil
            materialBackgroundView.isHidden = true
        case .blur(let style):
            materialEffectView.effect = UIBlurEffect(style: style)
            materialBackgroundView.isHidden = false
        case .liquid(let tintColor, let interactive):
            if #available(iOS 26.0, *) {
                let effect = UIGlassEffect(style: .regular)
                effect.isInteractive = interactive
                effect.tintColor = tintColor
                materialEffectView.effect = effect
                materialBackgroundView.isHidden = false
            } else {
                materialEffectView.effect = UIBlurEffect(style: .systemThinMaterial)
                materialBackgroundView.isHidden = false
            }
        }
    }

    func setMaterialCornerRadius(_ radius: CGFloat) {
        materialBackgroundView.layer.cornerRadius = radius
        materialBackgroundView.layer.masksToBounds = true
        materialEffectView.layer.cornerRadius = radius
        materialEffectView.layer.masksToBounds = true
        if #available(iOS 13.0, *) {
            materialBackgroundView.layer.cornerCurve = .continuous
            materialEffectView.layer.cornerCurve = .continuous
        }
    }

    public func setDropInteractionDelegate(delegate: ChatDropInteractionDelegate) {
        dropInteraction.delegate = delegate
    }

    // MARK: - Image Paste Support
    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == NSSelectorFromString("paste:") && UIPasteboard.general.hasImagesExtended {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    open override func paste(_ sender: Any?) {
        guard let image = UIPasteboard.general.imageExtended else {
            return super.paste(sender)
        }
        imagePasteDelegate?.onImagePasted(image: image)
    }
}

extension ChatInputTextView: UIDropInteractionDelegate {
    public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return dropInteraction.dropInteraction(canHandle: session)
    }

    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return dropInteraction.dropInteraction(sessionDidUpdate: session)
    }

    public func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        dropInteraction.dropInteraction(performDrop: session)
    }
}

public protocol ChatInputTextViewPasteDelegate: AnyObject {
    func onImagePasted(image: UIImage)
}

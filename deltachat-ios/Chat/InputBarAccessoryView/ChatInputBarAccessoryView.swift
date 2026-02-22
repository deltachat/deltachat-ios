import DcCore
import UIKit

final class ChatInputBarAccessoryView: InputBarAccessoryView {

    enum Mode {
        case composer
        case nonComposer
    }

    private enum AppliedEffectState {
        case composerLiquid
        case composerBlur
        case legacyBlur
    }

    private weak var attachButton: InputBarButtonItem?

    private var mode: Mode = .composer
    private var isSendEnabled = false
    private var appliedEffectState: AppliedEffectState?

    private let composerBlurEffect = UIBlurEffect(style: .systemChromeMaterial)
    private let legacyBlurEffect = UIBlurEffect(style: .systemMaterial)
    private let composerShadowFadeLayer = CAGradientLayer()

    private let attachIcon = UIImage(named: "ic_attach_file_36pt")?
        .withRenderingMode(.alwaysTemplate)
    private let sendIcon = UIImage(named: "paper_plane")?.withRenderingMode(
        .alwaysTemplate
    )
    private let scrollIcon = UIImage(systemName: "chevron.down")

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
    }

    override func setup() {
        super.setup()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceTransparencyStatusDidChange),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
        applyCurrentAppearance(animatedSendTransition: false)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if !scrollDownButton.isHidden
            && scrollDownButton.point(
                inside: convert(point, to: scrollDownButton),
                with: event
            )
        {
            return true
        }
        return super.point(inside: point, with: event)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !scrollDownButton.isHidden {
            let scrollButtonViewPoint = scrollDownButton.convert(
                point,
                from: self
            )
            if let view = scrollDownButton.hitTest(
                scrollButtonViewPoint,
                with: event
            ) {
                return view
            }
        }
        return super.hitTest(point, with: event)
    }

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard shouldReapplyAppearance(for: previousTraitCollection) else {
            return
        }
        applyCurrentAppearance(animatedSendTransition: false)
    }

    override func inputTextViewDidBeginEditing() {
        super.inputTextViewDidBeginEditing()
        guard mode == .composer else { return }
        styleTextViewForComposer(inputTextView)
    }

    override func inputTextViewDidEndEditing() {
        super.inputTextViewDidEndEditing()
        guard mode == .composer else { return }
        styleTextViewForComposer(inputTextView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if composerShadowFadeLayer.superlayer != nil {
            composerShadowFadeLayer.frame = backgroundView.bounds
        }
    }

    override func configure(draft: DraftModel) {
        hasDraft = !draft.isEditing && draft.attachment != nil
        hasQuote = !draft.isEditing && draft.quoteText != nil
        leftStackView.isHidden = draft.isEditing
        rightStackView.isHidden = draft.isEditing
        maxTextViewHeight = calculateMaxTextViewHeight()
    }

    override func cancel() {
        hasDraft = false
        hasQuote = false
        maxTextViewHeight = calculateMaxTextViewHeight()
    }

    func bindComposerAttachButton(_ button: InputBarButtonItem) {
        guard attachButton !== button else { return }
        attachButton = button
        applyCurrentAppearance(animatedSendTransition: false)
    }

    func applyComposerMode() {
        guard mode != .composer else { return }
        mode = .composer
        applyCurrentAppearance(animatedSendTransition: false)
    }

    func applyNonComposerMode() {
        guard mode != .nonComposer else { return }
        mode = .nonComposer
        applyCurrentAppearance(animatedSendTransition: false)
    }

    func updateSendEnabled(_ isEnabled: Bool) {
        guard isSendEnabled != isEnabled else { return }
        isSendEnabled = isEnabled
        switch mode {
        case .composer:
            styleSendButtonForComposer(sendButton, animated: true)
        case .nonComposer:
            styleSendButtonForLegacy(sendButton, animated: true)
        }
    }

    @objc private func reduceTransparencyStatusDidChange() {
        applyCurrentAppearance(animatedSendTransition: false)
    }

    private func applyCurrentAppearance(animatedSendTransition: Bool) {
        switch mode {
        case .composer:
            isTranslucent = true
            separatorLine.isHidden = true
            if #available(iOS 26.0, *) {
                applyEffectStateIfNeeded(.composerLiquid)
                backgroundView.backgroundColor = .clear
                applyComposerShadowFade()
            } else {
                applyEffectStateIfNeeded(.composerBlur)
                backgroundView.backgroundColor = DcColors.defaultTransparentBackgroundColor
            }
            topStackView.backgroundColor = UIColor.themeColor(
                light: UIColor(white: 1.0, alpha: 0.18),
                dark: UIColor(white: 0.22, alpha: 0.22)
            )
            topStackView.layer.cornerRadius = 14
            topStackView.layer.masksToBounds = true
            styleTextViewForComposer(inputTextView)
            styleAttachButtonForComposer()
            styleScrollDownButtonForComposer(scrollDownButton)
            styleSendButtonForComposer(
                sendButton,
                animated: animatedSendTransition
            )
        case .nonComposer:
            isTranslucent = true
            separatorLine.isHidden = false
            separatorLine.backgroundColor = DcColors.colorDisabled
            applyEffectStateIfNeeded(.legacyBlur)
            backgroundView.backgroundColor = DcColors.defaultTransparentBackgroundColor
            removeComposerShadowFade()
            topStackView.backgroundColor = .clear
            topStackView.layer.cornerRadius = 0
            topStackView.layer.masksToBounds = false
            styleTextViewForLegacy(inputTextView)
            styleAttachButtonForLegacy()
            styleScrollDownButtonForLegacy(scrollDownButton)
            styleSendButtonForLegacy(
                sendButton,
                animated: animatedSendTransition
            )
        }
    }

    private func applyEffectStateIfNeeded(_ state: AppliedEffectState) {
        guard appliedEffectState != state else { return }

        switch state {
        case .composerBlur:
            setBlurEffect(composerBlurEffect)
        case .legacyBlur:
            setBlurEffect(legacyBlurEffect)
        case .composerLiquid:
            if #available(iOS 26.0, *) {
                let containerEffect = UIGlassContainerEffect()
                containerEffect.spacing = 20
                setBlurEffect(containerEffect)
            }
        }
        appliedEffectState = state
    }

    private func setBlurEffect(_ effect: UIVisualEffect?) {
        UIView.performWithoutAnimation {
            blurView.effect = effect
        }
    }

    private func composerFrostedButtonColor() -> UIColor {
        UIColor.themeColor(
            light: UIColor(white: 1.0, alpha: 0.46),
            dark: UIColor(white: 0.15, alpha: 0.3)
        )
    }

    private func applyComposerShadowFade() {
        if composerShadowFadeLayer.superlayer !== backgroundView.layer {
            backgroundView.layer.insertSublayer(composerShadowFadeLayer, at: 0)
        }
        composerShadowFadeLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        composerShadowFadeLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        composerShadowFadeLayer.locations = [0.0, 0.55, 1.0]
        composerShadowFadeLayer.colors = composerShadowFadeColors()
        composerShadowFadeLayer.frame = backgroundView.bounds
    }

    private func removeComposerShadowFade() {
        composerShadowFadeLayer.removeFromSuperlayer()
    }

    private func composerShadowFadeColors() -> [CGColor] {
        let top = UIColor.clear.cgColor
        let middle = UIColor.themeColor(
            light: UIColor(white: 0.0, alpha: 0.3),
            dark: UIColor(white: 0.0, alpha: 0.6)
        ).cgColor
        let bottom = UIColor.themeColor(
            light: UIColor(white: 0.0, alpha: 0.6),
            dark: UIColor(white: 0.0, alpha: 0.8)
        ).cgColor
        return [top, middle, bottom]
    }

    private func shouldReapplyAppearance(
        for previousTraitCollection: UITraitCollection?
    ) -> Bool {
        guard let previousTraitCollection else { return true }
        if traitCollection.hasDifferentColorAppearance(
            comparedTo: previousTraitCollection
        ) {
            return true
        }
        if traitCollection.accessibilityContrast
            != previousTraitCollection.accessibilityContrast
        {
            return true
        }
        if traitCollection.userInterfaceLevel
            != previousTraitCollection.userInterfaceLevel
        {
            return true
        }
        return false
    }

    private func styleTextViewForComposer(_ textView: ChatInputTextView) {
        textView.layer.cornerRadius = 16
        textView.layer.masksToBounds = true
        textView.setMaterialCornerRadius(16)

        if UIAccessibility.isReduceTransparencyEnabled {
            textView.applyMaterialBackground(mode: .none)
            textView.backgroundColor = UIColor.themeColor(
                light: .white,
                dark: UIColor(white: 0.18, alpha: 1)
            )
            textView.layer.borderWidth = 1
            textView.layer.borderColor = DcColors.colorDisabled.cgColor
            return
        }

        if #available(iOS 26.0, *) {
            textView.applyMaterialBackground(
                mode: .liquid(tintColor: nil, interactive: true)
            )
            textView.backgroundColor = .clear
            textView.layer.borderWidth = 0
            textView.layer.borderColor = UIColor.clear.cgColor
        } else {
            textView.applyMaterialBackground(mode: .blur(.systemThinMaterial))
            textView.backgroundColor = .clear
            textView.layer.borderWidth = 1 / UIScreen.main.scale
            textView.layer.borderColor =
                UIColor.themeColor(
                    light: UIColor(white: 1, alpha: 0.35),
                    dark: UIColor(white: 1, alpha: 0.18)
                ).cgColor
        }
    }

    private func styleTextViewForLegacy(_ textView: ChatInputTextView) {
        textView.setMaterialCornerRadius(13)
        textView.applyMaterialBackground(mode: .none)
        textView.backgroundColor = DcColors.inputFieldColor
        textView.layer.borderColor = DcColors.colorDisabled.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 13
        textView.layer.masksToBounds = true
    }

    private func styleAttachButtonForComposer() {
        guard let attachButton else { return }

        if UIAccessibility.isReduceTransparencyEnabled {
            clearConfiguration(attachButton)
            attachButton.image = attachIcon
            attachButton.tintColor = DcColors.primary
            attachButton.backgroundColor = UIColor.themeColor(
                light: UIColor(white: 0.92, alpha: 1),
                dark: UIColor(white: 0.2, alpha: 1)
            )
            attachButton.layer.cornerRadius = 20
            attachButton.layer.borderColor = DcColors.colorDisabled.cgColor
            attachButton.layer.borderWidth = 1 / UIScreen.main.scale
            attachButton.layer.masksToBounds = true
            return
        }

        if #available(iOS 26.0, *) {
            var configuration = UIButton.Configuration.glass()
            configuration.image = attachIcon
            configuration.cornerStyle = .capsule
            configuration.baseForegroundColor = .label
            configuration.contentInsets = NSDirectionalEdgeInsets(
                top: 5,
                leading: 5,
                bottom: 5,
                trailing: 5
            )
            setConfiguration(configuration, on: attachButton)
            attachButton.setImage(attachIcon, for: .normal)
            attachButton.tintColor = .label
            attachButton.backgroundColor = composerFrostedButtonColor()
            attachButton.layer.borderWidth = 0
        } else {
            clearConfiguration(attachButton)
            attachButton.image = attachIcon
            attachButton.tintColor = DcColors.primary
            attachButton.backgroundColor = UIColor.themeColor(
                light: UIColor(white: 1, alpha: 0.24),
                dark: UIColor(white: 1, alpha: 0.12)
            )
            attachButton.layer.cornerRadius = 20
            attachButton.layer.borderColor =
                UIColor.themeColor(
                    light: UIColor(white: 1, alpha: 0.40),
                    dark: UIColor(white: 1, alpha: 0.20)
                ).cgColor
            attachButton.layer.borderWidth = 1 / UIScreen.main.scale
        }
        attachButton.layer.masksToBounds = true
    }

    private func styleAttachButtonForLegacy() {
        guard let attachButton else { return }
        clearConfiguration(attachButton)
        attachButton.image = attachIcon
        attachButton.tintColor = DcColors.primary
        attachButton.backgroundColor = .clear
        attachButton.layer.cornerRadius = 0
        attachButton.layer.borderWidth = 0
        attachButton.layer.masksToBounds = false
    }

    private func styleScrollDownButtonForComposer(_ button: UIButton) {
        if UIAccessibility.isReduceTransparencyEnabled {
            clearConfiguration(button)
            button.setImage(scrollIcon, for: .normal)
            button.tintColor = DcColors.defaultInverseColor
            button.backgroundColor = UIColor.themeColor(
                light: .white,
                dark: UIColor(white: 0.2, alpha: 1)
            )
            button.layer.borderColor = DcColors.colorDisabled.cgColor
            button.layer.borderWidth = 1 / UIScreen.main.scale
            button.layer.cornerRadius = 20
            button.layer.masksToBounds = true
            return
        }

        if #available(iOS 26.0, *) {
            var configuration = UIButton.Configuration.glass()
            configuration.image = scrollIcon
            configuration.cornerStyle = .capsule
            configuration.baseForegroundColor = DcColors.defaultInverseColor
            setConfiguration(configuration, on: button)
            button.backgroundColor = composerFrostedButtonColor()
            button.layer.borderWidth = 0
        } else {
            clearConfiguration(button)
            button.setImage(scrollIcon, for: .normal)
            button.tintColor = DcColors.defaultInverseColor
            button.backgroundColor = UIColor.themeColor(
                light: UIColor(white: 1, alpha: 0.24),
                dark: UIColor(white: 1, alpha: 0.12)
            )
            button.layer.borderColor =
                UIColor.themeColor(
                    light: UIColor(white: 1, alpha: 0.40),
                    dark: UIColor(white: 1, alpha: 0.20)
                ).cgColor
            button.layer.borderWidth = 1 / UIScreen.main.scale
        }
        button.layer.cornerRadius = 20
        button.layer.masksToBounds = true
    }

    private func styleScrollDownButtonForLegacy(_ button: UIButton) {
        clearConfiguration(button)
        button.setImage(scrollIcon, for: .normal)
        button.tintColor = DcColors.defaultInverseColor
        button.backgroundColor = DcColors.defaultBackgroundColor
        button.layer.cornerRadius = 20
        button.layer.borderColor = DcColors.colorDisabled.cgColor
        button.layer.borderWidth = 1
        button.layer.masksToBounds = true
    }

    private func styleSendButtonForComposer(
        _ sendButton: InputBarSendButton,
        animated: Bool
    ) {
        let applyStyle: () -> Void = {
            if UIAccessibility.isReduceTransparencyEnabled {
                self.clearConfiguration(sendButton)
                sendButton.image = self.sendIcon
                sendButton.tintColor = .white
                sendButton.backgroundColor =
                    self.isSendEnabled
                    ? DcColors.primary : DcColors.colorDisabled
                sendButton.layer.borderWidth = 0
            } else if #available(iOS 26.0, *) {
                let fallbackImage =
                    self.sendIcon ?? sendButton.image(for: .normal)
                    ?? UIImage(systemName: "paperplane.fill")
                if self.isSendEnabled {
                    self.clearConfiguration(sendButton)
                    sendButton.setImage(fallbackImage, for: .normal)
                    sendButton.tintColor = .white
                    sendButton.backgroundColor = DcColors.primary
                } else {
                    var configuration = UIButton.Configuration.glass()
                    configuration.image = fallbackImage
                    configuration.cornerStyle = .capsule
                    configuration.baseForegroundColor = .secondaryLabel
                    configuration.contentInsets = NSDirectionalEdgeInsets(
                        top: 5,
                        leading: 5,
                        bottom: 5,
                        trailing: 5
                    )
                    self.setConfiguration(configuration, on: sendButton)
                    sendButton.setImage(fallbackImage, for: .normal)
                    sendButton.tintColor = .secondaryLabel
                    sendButton.backgroundColor = self.composerFrostedButtonColor()
                }
                sendButton.layer.borderWidth = 0
            } else {
                self.clearConfiguration(sendButton)
                sendButton.image = self.sendIcon
                sendButton.tintColor = .white
                sendButton.backgroundColor =
                    self.isSendEnabled
                    ? DcColors.primary : DcColors.colorDisabled
                sendButton.layer.borderColor =
                    UIColor.themeColor(
                        light: UIColor(white: 1, alpha: 0.40),
                        dark: UIColor(white: 1, alpha: 0.20)
                    ).cgColor
                sendButton.layer.borderWidth = 1 / UIScreen.main.scale
            }

            sendButton.layer.cornerRadius = 20
            sendButton.layer.masksToBounds = true
        }

        if animated {
            UIView.transition(
                with: sendButton,
                duration: 0.20,
                options: [.transitionCrossDissolve, .allowUserInteraction],
                animations: applyStyle
            )
        } else {
            applyStyle()
        }
    }

    private func styleSendButtonForLegacy(
        _ sendButton: InputBarSendButton,
        animated: Bool
    ) {
        let applyStyle: () -> Void = {
            self.clearConfiguration(sendButton)
            sendButton.image = self.sendIcon
            sendButton.tintColor = .white
            sendButton.backgroundColor =
                self.isSendEnabled ? DcColors.primary : DcColors.colorDisabled
            sendButton.layer.cornerRadius = 20
            sendButton.layer.borderWidth = 0
            sendButton.layer.masksToBounds = true
        }

        if animated {
            UIView.transition(
                with: sendButton,
                duration: 0.20,
                options: [.transitionCrossDissolve, .allowUserInteraction],
                animations: applyStyle
            )
        } else {
            applyStyle()
        }
    }

    private func clearConfiguration(_ button: UIButton) {
        if #available(iOS 15.0, *) {
            button.configuration = nil
        }
    }

    @available(iOS 15.0, *)
    private func setConfiguration(
        _ configuration: UIButton.Configuration,
        on button: UIButton
    ) {
        button.configuration = configuration
    }
}

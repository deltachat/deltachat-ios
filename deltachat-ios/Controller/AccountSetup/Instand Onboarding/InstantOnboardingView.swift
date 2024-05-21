import UIKit

class InstantOnboardingView: UIView {

    let imageButton: UIButton

    let nameTextField: UITextField
    let hintLabel: UILabel
    private let hintLabelWrapper: UIView
    let privacyButton: UIButton
    private let privacyButtonWrapper: UIView
    let agreeButton: UIButton
    let otherOptionsButton: UIButton

    private let contentStackView: UIStackView
    private(set) var contentScrollView: UIScrollView

    init(avatarImage: UIImage?, name: String?, customProvider: String?) {

        imageButton = UIButton()
        imageButton.translatesAutoresizingMaskIntoConstraints = false
        if let avatarImage {
            imageButton.setImage(avatarImage, for: .normal)
        } else {
            imageButton.setImage(UIImage(named: "person.crop.circle"), for: .normal)
        }
        imageButton.layer.masksToBounds = true
        imageButton.layer.cornerRadius = 75
        imageButton.contentVerticalAlignment = .fill
        imageButton.contentHorizontalAlignment = .fill

        nameTextField = UITextField()
        nameTextField.text = name
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.placeholder = String.localized("pref_your_name")
        nameTextField.borderStyle = .roundedRect

        hintLabel = UILabel()
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.numberOfLines = 0
        hintLabel.text = String.localized("set_name_and_avatar_explain")

        hintLabelWrapper = UIView()
        hintLabelWrapper.translatesAutoresizingMaskIntoConstraints = false
        hintLabelWrapper.addSubview(hintLabel)

        agreeButton = UIButton()
        agreeButton.setTitle(String.localized("instant_onboarding_create"), for: .normal)
        agreeButton.translatesAutoresizingMaskIntoConstraints = false
        agreeButton.layer.cornerRadius = 8
        agreeButton.contentEdgeInsets.top = 8
        agreeButton.contentEdgeInsets.bottom = 8

        privacyButton = UIButton(type: .system)
        privacyButton.translatesAutoresizingMaskIntoConstraints = false
        privacyButtonWrapper = UIView()
        privacyButtonWrapper.translatesAutoresizingMaskIntoConstraints = false
        privacyButtonWrapper.addSubview(privacyButton)

        otherOptionsButton = UIButton(type: .system)
        otherOptionsButton.setTitle(String.localized("instant_onboarding_show_more_instances"), for: .normal)
        otherOptionsButton.translatesAutoresizingMaskIntoConstraints = false

        contentStackView = UIStackView(arrangedSubviews: [imageButton, nameTextField, hintLabelWrapper, privacyButtonWrapper, agreeButton, otherOptionsButton, UIView()])
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.alignment = .center
        contentStackView.distribution = .fill
        contentStackView.setCustomSpacing(32, after: imageButton)
        contentStackView.setCustomSpacing(16, after: nameTextField)
        contentStackView.setCustomSpacing(8, after: hintLabelWrapper)
        contentStackView.setCustomSpacing(16, after: privacyButtonWrapper)
        contentStackView.setCustomSpacing(16, after: agreeButton)

        contentScrollView = UIScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.addSubview(contentStackView)
        contentScrollView.keyboardDismissMode = .onDrag

        super.init(frame: .zero)

        if #available(iOS 13.0, *) {
            backgroundColor = .systemGroupedBackground
            nameTextField.backgroundColor = .systemBackground
        } else {
            backgroundColor = .systemGray
        }

        addSubview(contentScrollView)

        setupConstraints()
        validateTextfield(text: nameTextField.text)
        updateContent(with: customProvider)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            contentScrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            contentScrollView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: contentScrollView.trailingAnchor),
            safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: contentScrollView.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: contentScrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: contentScrollView.leadingAnchor, constant: 16),
            contentScrollView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: 16),
            contentScrollView.bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor),

            contentStackView.widthAnchor.constraint(equalTo: contentScrollView.widthAnchor, constant: -32),
            contentStackView.heightAnchor.constraint(equalTo: contentScrollView.heightAnchor),
            nameTextField.widthAnchor.constraint(equalTo: contentStackView.widthAnchor),
            agreeButton.widthAnchor.constraint(equalTo: contentStackView.widthAnchor),

            imageButton.widthAnchor.constraint(equalToConstant: 150),
            imageButton.heightAnchor.constraint(equalToConstant: 150),

            privacyButtonWrapper.widthAnchor.constraint(equalTo: contentStackView.widthAnchor),
            privacyButton.topAnchor.constraint(equalTo: privacyButtonWrapper.topAnchor),
            privacyButton.leadingAnchor.constraint(equalTo: privacyButtonWrapper.leadingAnchor),
            privacyButtonWrapper.trailingAnchor.constraint(greaterThanOrEqualTo: privacyButton.trailingAnchor),
            privacyButtonWrapper.bottomAnchor.constraint(equalTo: privacyButton.bottomAnchor),

            hintLabelWrapper.widthAnchor.constraint(equalTo: contentStackView.widthAnchor),
            hintLabel.topAnchor.constraint(equalTo: hintLabelWrapper.topAnchor),
            hintLabel.leadingAnchor.constraint(equalTo: hintLabelWrapper.leadingAnchor),
            hintLabelWrapper.trailingAnchor.constraint(greaterThanOrEqualTo: hintLabel.trailingAnchor),
            hintLabelWrapper.bottomAnchor.constraint(equalTo: hintLabel.bottomAnchor),
        ]

        NSLayoutConstraint.activate(constraints)
    }

    func validateTextfield(text: String?) {
        let buttonShouldBeEnabled: Bool

        if let text {
            buttonShouldBeEnabled = (text.isEmpty == false)
        } else {
            buttonShouldBeEnabled = false
        }
        agreeButton.isEnabled = buttonShouldBeEnabled

        if buttonShouldBeEnabled {
            agreeButton.backgroundColor = .systemBlue
        } else {
            agreeButton.backgroundColor = UIColor.systemGray.withAlphaComponent(0.3)
        }
    }

    func updateContent(with customProvider: String?) {
        if let customProvider {
            privacyButton.setTitle(String.localized(stringID: "instant_onboarding_agree_instance", parameter: customProvider), for: .normal)
        } else {
            privacyButton.setTitle(String.localized("instant_onboarding_agree_default"), for: .normal)
        }
    }
}

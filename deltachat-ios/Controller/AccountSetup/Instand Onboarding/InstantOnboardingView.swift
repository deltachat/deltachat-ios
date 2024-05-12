import UIKit

class InstantOnboardingView: UIView {

    let nameTextField: UITextField
    let hintLabel: UILabel
    let agreeButton: UIButton

    private let contentStackView: UIStackView
    private let contentScrollView: UIScrollView

    override init(frame: CGRect) {

        nameTextField = UITextField()
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.placeholder = String.localized("pref_your_name")
        nameTextField.borderStyle = .roundedRect

        hintLabel = UILabel()
        hintLabel.numberOfLines = 0
        hintLabel.text = String.localized("set_name_and_avatar_explain")

        agreeButton = UIButton()
        agreeButton.setTitle(String.localized("instant_onboarding_create"), for: .normal)
        agreeButton.translatesAutoresizingMaskIntoConstraints = false
        agreeButton.layer.cornerRadius = 8
        agreeButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.6)
        agreeButton.contentEdgeInsets.top = 8
        agreeButton.contentEdgeInsets.bottom = 8

        contentStackView = UIStackView(arrangedSubviews: [nameTextField, hintLabel, agreeButton])
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.alignment = .center
        contentStackView.spacing = 8

        contentScrollView = UIScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.addSubview(contentStackView)
        contentScrollView.keyboardDismissMode = .onDrag

        super.init(frame: frame)

        if #available(iOS 13.0, *) {
            backgroundColor = .systemGroupedBackground
            nameTextField.backgroundColor = .systemBackground
        } else {
            backgroundColor = .systemGray
        }

        addSubview(contentScrollView)

        setupConstraints()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            contentScrollView.topAnchor.constraint(equalTo: topAnchor),
            contentScrollView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: contentScrollView.trailingAnchor),
            bottomAnchor.constraint(equalTo: contentScrollView.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: contentScrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: contentScrollView.leadingAnchor, constant: 16),
            contentScrollView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: 16),
            contentScrollView.bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor),

            contentStackView.widthAnchor.constraint(equalTo: contentScrollView.widthAnchor, constant: -32),
            nameTextField.widthAnchor.constraint(equalTo: contentStackView.widthAnchor),
            agreeButton.widthAnchor.constraint(equalTo: contentStackView.widthAnchor),
        ]

        NSLayoutConstraint.activate(constraints)
    }
}

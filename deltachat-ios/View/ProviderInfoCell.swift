import UIKit
import DcCore

enum ProviderInfoStatus: Int {
    case preparation = 2
    case broken = 3
 }

class ProviderInfoCell: UITableViewCell {

    private struct ColorSet {
        let backgroundColor: UIColor
        let tintColor: UIColor
    }

    private let fontSize: CGFloat = 14

    private let brokenColorSet: ColorSet = ColorSet(
        backgroundColor: DcColors.providerBrokenBackground,
        tintColor: UIColor.white
    )

    private let preparationColorSet: ColorSet = ColorSet(
        backgroundColor: DcColors.providerPreparationBackground,
        tintColor: UIColor.black
    )

    var onInfoButtonPressed: VoidFunction?

    private var hintBackgroundView: UIView = {
        let view = UIView()
        return view
    }()

    private lazy var hintLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: fontSize)
        return label
    }()

    private lazy var infoButton: UIButton = {
        let button = UIButton()
        let title = String.localized("more_info_desktop").markAsExternal()
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: fontSize)
        button.addTarget(self, action: #selector(infoButtonPressed(_:)), for: .touchUpInside)
        return button
    }()

    init() {
        super.init(style: .default, reuseIdentifier: nil)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        // ... no highlight
    }

    private func setupSubviews() {

        let margin: CGFloat = 15
        let padding: CGFloat = 10

        contentView.addSubview(hintBackgroundView)
        hintBackgroundView.addSubview(hintLabel)
        hintBackgroundView.addSubview(infoButton)

        hintBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        infoButton.translatesAutoresizingMaskIntoConstraints = false

        hintBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin).isActive = true
        hintBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: margin).isActive = true
        hintBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin).isActive = true
        hintBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -margin).isActive = true

        hintLabel.leadingAnchor.constraint(equalTo: hintBackgroundView.leadingAnchor, constant: padding).isActive = true
        hintLabel.topAnchor.constraint(equalTo: hintBackgroundView.topAnchor, constant: padding).isActive = true
        hintLabel.trailingAnchor.constraint(equalTo: hintBackgroundView.trailingAnchor, constant: -padding).isActive = true

        infoButton.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: padding).isActive = true
        infoButton.leadingAnchor.constraint(equalTo: hintBackgroundView.leadingAnchor, constant: padding).isActive = true
        infoButton.bottomAnchor.constraint(equalTo: hintBackgroundView.bottomAnchor, constant: -padding).isActive = true
    }

    // MARK: - update
    func updateInfo(hint text: String?, hintType: ProviderInfoStatus?) {
        hintLabel.text = text
        switch hintType {
        case .preparation:
            hintBackgroundView.backgroundColor = preparationColorSet.backgroundColor
            hintLabel.textColor = preparationColorSet.tintColor
            infoButton.setTitleColor(preparationColorSet.tintColor, for: .normal)
        case .broken:
            hintBackgroundView.backgroundColor = brokenColorSet.backgroundColor
            hintLabel.textColor = brokenColorSet.tintColor
            infoButton.setTitleColor(brokenColorSet.tintColor, for: .normal)
        case .none:
            break
        }
    }

    // MARK: - actions
    @objc func infoButtonPressed(_: UIButton) {
        onInfoButtonPressed?()
    }
}

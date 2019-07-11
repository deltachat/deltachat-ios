import UIKit

class ChatTitleView: UIView {

	private var titleLabel: UILabel = {
		let titleLabel = UILabel()
		titleLabel.backgroundColor = UIColor.clear
		titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
		titleLabel.textAlignment = .center
		titleLabel.adjustsFontSizeToFitWidth = true
		return titleLabel
	}()

	private var subtitleLabel: UILabel = {
		let subtitleLabel = UILabel()
		subtitleLabel.font = UIFont.systemFont(ofSize: 12)
		subtitleLabel.textAlignment = .center
		return subtitleLabel
	}()

	init() {
		super.init(frame: .zero)
		setupSubviews()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func setupSubviews() {
		addSubview(titleLabel)
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
		titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
		titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
		titleLabel.topAnchor.constraint(equalTo: topAnchor).isActive = true

		addSubview(subtitleLabel)
		subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
		subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0).isActive = true
		subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0).isActive = true
		subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0).isActive = true
		subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0).isActive = true
	}

	func updateTitleView(title: String, subtitle: String?, baseColor: UIColor = .darkText) {
		subtitleLabel.textColor = baseColor.withAlphaComponent(0.95)
		titleLabel.textColor = baseColor
		titleLabel.text = title
		subtitleLabel.text = subtitle
	}
}

import UIKit
import DcCore
public class BaseMessageCell: UITableViewCell {

    static var defaultPadding: CGFloat = 12

    lazy var avatarView: InitialsBadge = {
        let view = InitialsBadge(size: 28)
        view.setColor(UIColor.gray)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var topLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "title"
        label.font = UIFont.preferredFont(for: .caption1, weight: .regular)
        return label
    }()

    lazy var mainContentView: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .horizontal
        return view
    }()

    lazy var bottomContentView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [bottomLabel])
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .horizontal
        return view
    }()
    lazy var bottomLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(for: .caption1, weight: .regular)
        return label
    }()

    private lazy var contentContainer: UIStackView = {
        let view = UIStackView(arrangedSubviews: [topLabel, mainContentView, bottomContentView])
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    func setupSubviews() {
        contentView.addSubview(avatarView)
        contentView.addSubview(contentContainer)

        contentView.addConstraints([
            avatarView.constraintAlignTopTo(contentView, paddingTop: defaultPadding),
            avatarView.constraintAlignLeadingTo(contentView),
            avatarView.constraintAlignBottomTo(contentView, paddingBottom: defaultPadding, priority: .defaultLow),
            contentContainer.constraintToTrailingOf(avatarView, paddingLeading: defaultPadding),
            contentContainer.constraintAlignTrailingTo(contentView, paddingTrailing: defaultPadding),
            contentContainer.constraintAlignTopTo(contentView, paddingTop: defaultPadding),
            contentContainer.constraintAlignBottomTo(contentView, paddingBottom: defaultPadding)
        ])
    }
    
    func update(msg: DcMsg) {
        topLabel.text = msg.fromContact.displayName
        avatarView.setName(msg.fromContact.displayName)
        avatarView.setColor(msg.fromContact.color)
    }

    override public func prepareForReuse() {
        textLabel?.text = nil
        textLabel?.attributedText = nil
        topLabel.text = nil
        avatarView.reset()

    }
    
}

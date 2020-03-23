import UIKit

class WelcomeViewController: UIViewController, UITableViewDataSource {

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.allowsSelection = false
        return tableView
    }()

    private let welcomeCell = WelcomeCell()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.rowHeight = view.frame.height
    }

    private func setupSubviews() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        tableView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        tableView.rowHeight = view.frame.height
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return welcomeCell
    }
}


class WelcomeCell: UITableViewCell {

    private let fontSize: CGFloat = 24 // probably better to make larger for ipad

    private var logoView: UIImageView = {
        let image = #imageLiteral(resourceName: "ic_launcher").withRenderingMode(.alwaysOriginal)
        let view = UIImageView(image: image)
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome to Delta Chat"
        label.textColor = DcColors.grayTextColor
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "The messenger with the broadest audience in the world. Free and independent."
        label.font = UIFont.systemFont(ofSize: 22, weight: .regular)
        label.textColor = DcColors.grayTextColor
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    init() {
        super.init(style: .default, reuseIdentifier: nil)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        _ = [subtitleLabel, titleLabel, logoView].map {
            contentView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        }

        // subtitleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        subtitleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        subtitleLabel.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.8).isActive = true

        titleLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -20).isActive = true

        let layoutGuide = UILayoutGuide()
        contentView.addLayoutGuide(layoutGuide)

        layoutGuide.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0).isActive = true
        layoutGuide.bottomAnchor.constraint(equalTo: titleLabel.topAnchor).isActive = true

        logoView.heightAnchor.constraint(equalTo: layoutGuide.heightAnchor, multiplier: 0.3).isActive = true
        logoView.widthAnchor.constraint(equalTo: logoView.heightAnchor).isActive = true
        logoView.bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor, constant: -20).isActive = true


    }
}

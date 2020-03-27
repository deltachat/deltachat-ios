import UIKit

class WelcomeViewController: UIViewController, UITableViewDataSource {

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()

        return scrollView
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.allowsSelection = false
//        tableView.rowHeight = UITableView.automaticDimension
//        tableView.estimatedRowHeight = UITableView.automaticDimension
        return tableView
    }()

    private let welcomeCell = WelcomeCell()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

  //      welcomeCell.minumumCellHeight = view.frame.height
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//         tableView.estimatedRowHeight = view.frame.height
//        welcomeCell.minumumCellHeight = size.height
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        welcomeCell.minumumCellHeight = view.frame.height
        tableView.reloadData()

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

    var minumumCellHeight: CGFloat = 0 {
        didSet {
            containerMinimumHeightConstraint.constant = 1000
        }
    }

    var onLogin: VoidFunction?
    var onScanQRCode: VoidFunction?
    var onImportBackup: VoidFunction?


    private let fontSize: CGFloat = 24 // probably better to make larger for ipad

    private var container = UIView()

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

    private lazy var loginButton: UIButton = {
        let button = UIButton(type: .roundedRect)
        let title = "log in to your server".uppercased()
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = DcColors.primary
        let insets = button.contentEdgeInsets
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 15, bottom: 8, right: 15)
        button.layer.cornerRadius = 5
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(loginButtonPressed(_:)), for: .touchUpInside)
        return button
    }()

    private lazy var qrCodeButton: UIButton = {
        let button = UIButton()
        let title = "Scan QR code"
        button.setTitleColor(UIColor.systemBlue, for: .normal)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: #selector(qrCodeButtonPressed(_:)), for: .touchUpInside)
        return button
    }()

    private lazy var importBackupButton: UIButton = {
        let button = UIButton()
        let title = "Import backup"
        button.setTitleColor(UIColor.systemBlue, for: .normal)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: #selector(importBackupButtonPressed(_:)), for: .touchUpInside)
        return button
    }()

    private var containerMinimumHeightConstraint: NSLayoutConstraint!


    init() {
        super.init(style: .default, reuseIdentifier: nil)
        setupSubviews()
        contentView.makeBorder()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {

        contentView.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false

        container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        container.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
        container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
        container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true

        containerMinimumHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: 100)
        containerMinimumHeightConstraint.isActive = true

/*

        let verticalStackview = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        verticalStackview.axis = .vertical
        verticalStackview.spacing = 20
        contentView.addSubview(verticalStackview)
        verticalStackview.translatesAutoresizingMaskIntoConstraints = false
        verticalStackview.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0).isActive = true
        verticalStackview.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        verticalStackview.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.75).isActive = true

        contentView.addSubview(logoView)
        logoView.translatesAutoresizingMaskIntoConstraints = false
        logoView.heightAnchor.constraint(equalTo: verticalStackview.heightAnchor, multiplier: 0.75).isActive = true
        logoView.widthAnchor.constraint(equalTo: logoView.heightAnchor).isActive = true
        logoView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        logoView.bottomAnchor.constraint(equalTo: verticalStackview.topAnchor, constant: -20).isActive = true
        let logoTopAnchor = logoView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20) // this will allow the cell to grow if needed
        logoTopAnchor.priority = UILayoutPriority.defaultLow
        logoTopAnchor.isActive = true

        /*
        let buttonStackview = UIStackView(arrangedSubviews: [loginButton, qrCodeButton, importBackupButton])
        buttonStackview.axis = .vertical
        buttonStackview.spacing = 10
        buttonStackview.distribution = .fillProportionally
        contentView.addSubview(buttonStackview)
        buttonStackview.translatesAutoresizingMaskIntoConstraints = false
        buttonStackview.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        buttonStackview.topAnchor.constraint(equalTo: verticalStackview.bottomAnchor, constant: 30).isActive = true

        let buttonStackviewBottomAnchor = buttonStackview.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        buttonStackviewBottomAnchor.priority = .
        buttonStackviewBottomAnchor.isActive = true

        */
        contentView.addSubview(loginButton)
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        loginButton.topAnchor.constraint(equalTo: verticalStackview.bottomAnchor, constant: 20).isActive = true
        loginButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true

        contentView.addSubview(qrCodeButton)
        qrCodeButton.translatesAutoresizingMaskIntoConstraints = false
        qrCodeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        qrCodeButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 10).isActive = true

        contentView.addSubview(importBackupButton)
        importBackupButton.translatesAutoresizingMaskIntoConstraints = false
        importBackupButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        importBackupButton.topAnchor.constraint(equalTo: qrCodeButton.bottomAnchor, constant: 10).isActive = true
        let buttonStackviewBottomAnchor = importBackupButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        buttonStackviewBottomAnchor.priority = .defaultHigh
        buttonStackviewBottomAnchor.isActive = true

 */
    }

    // MARK: - actions
    @objc private func loginButtonPressed(_ sender: UIButton) {
        onLogin?()
    }

    @objc private func qrCodeButtonPressed(_ sender: UIButton) {
        onScanQRCode?()
    }

    @objc private func importBackupButtonPressed(_ sender: UIButton) {
        onImportBackup?()
    }
}

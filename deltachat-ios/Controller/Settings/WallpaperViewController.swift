import Foundation
import UIKit
import DcCore

class WallpaperViewController: UIViewController, MediaPickerDelegate {

    private let dcContext: DcContext

    private lazy var selectBackgroundButton: DynamicFontButton = {
        let btn = DynamicFontButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(String.localized("pref_background_btn_gallery"), for: .normal)
        btn.accessibilityLabel = String.localized("pref_background_btn_gallery")
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitleColor(.systemBlue, for: .normal)
        btn.setTitleColor(.gray, for: .highlighted)
        btn.titleLabel?.lineBreakMode = .byWordWrapping
        btn.titleLabel?.textAlignment = .center
        btn.contentHorizontalAlignment = .center
        btn.titleLabel?.font = UIFont.preferredFont(for: .body, weight: .regular)
        btn.titleLabel?.adjustsFontForContentSizeCategory = true
        btn.addTarget(self, action: #selector(onSelectBackgroundImage), for: .touchUpInside)
        return btn
    }()

    private lazy var selectDefaultButton: DynamicFontButton = {
        let btn = DynamicFontButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(String.localized("pref_background_btn_default"), for: .normal)
        btn.accessibilityLabel = String.localized("pref_background_btn_gallery")
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitleColor(.systemBlue, for: .normal)
        btn.setTitleColor(.gray, for: .highlighted)
        btn.titleLabel?.lineBreakMode = .byWordWrapping
        btn.titleLabel?.textAlignment = .center
        btn.contentHorizontalAlignment = .center
        btn.addTarget(self, action: #selector(onDefaultSelected), for: .touchUpInside)
        btn.titleLabel?.font = UIFont.preferredFont(for: .body, weight: .regular)
        btn.titleLabel?.adjustsFontForContentSizeCategory = true
        return btn
    }()

    lazy var blurView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .light)
        let view = UIVisualEffectView(effect: blurEffect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var container: UIStackView = {
        let container = UIStackView(arrangedSubviews: [selectDefaultButton, selectBackgroundButton])
        container.translatesAutoresizingMaskIntoConstraints = false
        container.distribution = .fillEqually
        container.axis = .horizontal
        container.alignment = .fill
        container.backgroundColor = DcColors.defaultTransparentBackgroundColor
        return container
    }()

    private lazy var backgroundContainer: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        if let backgroundImageName = UserDefaults.standard.string(forKey: Constants.Keys.backgroundImageName) {
            view.sd_setImage(with: Utils.getBackgroundImageURL(name: backgroundImageName),
                             placeholderImage: nil,
                             options: [.retryFailed, .refreshCached]) { [weak self] (_, error, _, _) in
                    if let error = error {
                        logger.error("Error loading background image: \(error.localizedDescription)" )
                        DispatchQueue.main.async {
                            self?.setDefault(view)
                        }
                    }
                }
        } else {
            setDefault(view)
        }

        return view
    }()

    private lazy var mediaPicker: MediaPicker = {
        let mediaPicker = MediaPicker(dcContext: dcContext, navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .systemGroupedBackground
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        self.title = String.localized("pref_background")
        setupSubviews()
    }

    private func setupSubviews() {
        view.addSubview(backgroundContainer)
        view.addSubview(blurView)
        view.addSubview(container)

        view.addConstraints([
            container.constraintAlignBottomTo(view),
            container.constraintAlignLeadingTo(view),
            container.constraintAlignTrailingTo(view),
            blurView.constraintAlignTopTo(container),
            blurView.constraintAlignLeadingTo(container),
            blurView.constraintAlignTrailingTo(container),
            blurView.constraintAlignBottomTo(container),
            backgroundContainer.constraintAlignBottomTo(view),
            backgroundContainer.constraintAlignLeadingTo(view),
            backgroundContainer.constraintAlignTrailingTo(view),
            backgroundContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])
     }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bottomSafeArea = view.safeAreaInsets.bottom
        selectBackgroundButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 8, bottom: bottomSafeArea + 12, right: 8)
        selectDefaultButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 8, bottom: bottomSafeArea + 12, right: 8)
    }

    @objc private func onSelectBackgroundImage() {
        mediaPicker.showGallery(allowCropping: true)
    }

    @objc private func onDefaultSelected() {
        setDefault(backgroundContainer)
        UserDefaults.standard.set(nil, forKey: Constants.Keys.backgroundImageName)
    }

    private func setDefault(_ imageView: UIImageView) {
        imageView.image = UIImage(named: traitCollection.userInterfaceStyle == .light ? "background_light" : "background_dark")
    }

    // MARK: MediaPickerDelegate
    func onImageSelected(image: UIImage) {
        if let path = ImageFormat.saveImage(image: image, name: Constants.backgroundImageName) {
            UserDefaults.standard.set(URL(fileURLWithPath: path).lastPathComponent, forKey: Constants.Keys.backgroundImageName)
            backgroundContainer.sd_setImage(with: URL(fileURLWithPath: path), placeholderImage: nil, options: .refreshCached, completed: nil)
        } else {
            logger.error("failed to save background image")
        }
    }
}

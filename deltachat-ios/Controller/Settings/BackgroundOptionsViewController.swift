import Foundation
import UIKit
import DcCore

class BackgroundOptionsViewController: UIViewController, MediaPickerDelegate {

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

    private lazy var selectColorButton: DynamicFontButton = {
        let btn = DynamicFontButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(String.localized("pref_background_custom_color"), for: .normal)
        btn.accessibilityLabel = String.localized("pref_background_custom_color")
        btn.setTitleColor(.systemBlue, for: .normal)
        btn.setTitleColor(.gray, for: .highlighted)
        btn.titleLabel?.lineBreakMode = .byWordWrapping
        btn.titleLabel?.textAlignment = .center
        btn.contentHorizontalAlignment = .center
        btn.titleLabel?.font = UIFont.preferredFont(for: .body, weight: .regular)
        btn.titleLabel?.adjustsFontForContentSizeCategory = true
        btn.addTarget(self, action: #selector(onSelectColor), for: .touchUpInside)
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
        let container = UIStackView(arrangedSubviews: [selectDefaultButton, selectBackgroundButton, selectColorButton])
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
        loadCurrentBackground(into: view)
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
        selectColorButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 8, bottom: bottomSafeArea + 12, right: 8)
    }

    @objc private func onSelectBackgroundImage() {
        mediaPicker.showGallery(allowCropping: true)
    }

    @objc private func onSelectColor() {
        if #available(iOS 14.0, *) {
            let colorPicker = UIColorPickerViewController()
            colorPicker.delegate = self
            colorPicker.selectedColor = getBackgroundColor() ?? .white
            colorPicker.title = String.localized("pref_background_custom_color")
            present(colorPicker, animated: true)
        } else {
            let alert = UIAlertController(
                title: String.localized("pref_background"),
                message: "Color picker requires iOS 14 or later",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func onDefaultSelected() {
        setDefault(backgroundContainer)
        UserDefaults.standard.set(nil, forKey: Constants.Keys.backgroundImageName)
        UserDefaults.standard.removeObject(forKey: Constants.Keys.customBackgroundColorKey)
    }

    private func setDefault(_ imageView: UIImageView) {
        imageView.image = UIImage(named: traitCollection.userInterfaceStyle == .light ? "background_light" : "background_dark")
        imageView.backgroundColor = nil
    }

    private func loadCurrentBackground(into imageView: UIImageView) {
        // Check for custom color first
        if let color = getBackgroundColor() {
            imageView.backgroundColor = color
            imageView.image = nil
        } else if let backgroundImageName = UserDefaults.standard.string(forKey: Constants.Keys.backgroundImageName) {
            // Load custom image
            imageView.backgroundColor = nil
            imageView.sd_setImage(with: Utils.getBackgroundImageURL(name: backgroundImageName),
                                 placeholderImage: nil,
                                 options: [.retryFailed, .refreshCached]) { [weak self] (_, error, _, _) in
                if let error = error {
                    logger.error("Error loading background image: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.setDefault(imageView)
                    }
                }
            }
        } else {
            // Use default
            setDefault(imageView)
        }
    }

    private func getBackgroundColor() -> UIColor? {
        if let colorData = UserDefaults.standard.data(forKey: Constants.Keys.customBackgroundColorKey),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
            return color
        }
        return nil
    }

    private func saveBackgroundColor(_ color: UIColor) {
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: Constants.Keys.customBackgroundColorKey)
            // Clear image when setting color
            UserDefaults.standard.set(nil, forKey: Constants.Keys.backgroundImageName)
        }
    }

    // MARK: MediaPickerDelegate
    func onImageSelected(image: UIImage) {
        if let path = ImageFormat.saveImage(image: image, name: Constants.backgroundImageName) {
            UserDefaults.standard.set(URL(fileURLWithPath: path).lastPathComponent, forKey: Constants.Keys.backgroundImageName)
            // Clear color when setting image
            UserDefaults.standard.removeObject(forKey: Constants.Keys.customBackgroundColorKey)
            backgroundContainer.backgroundColor = nil
            backgroundContainer.sd_setImage(with: URL(fileURLWithPath: path), placeholderImage: nil, options: .refreshCached, completed: nil)
        } else {
            logger.error("failed to save background image")
        }
    }
}

// MARK: - UIColorPickerViewControllerDelegate

@available(iOS 14.0, *)
extension BackgroundOptionsViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        saveBackgroundColor(viewController.selectedColor)
        backgroundContainer.image = nil
        backgroundContainer.backgroundColor = viewController.selectedColor
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        viewController.dismiss(animated: true)
    }
}

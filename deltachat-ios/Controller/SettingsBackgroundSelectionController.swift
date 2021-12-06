import Foundation
import UIKit
import DcCore

class SettingsBackgroundSelectionController: UIViewController, MediaPickerDelegate {

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

    private lazy var container: UIStackView = {
        let container = UIStackView(arrangedSubviews: [selectDefaultButton, selectBackgroundButton])
        container.translatesAutoresizingMaskIntoConstraints = false
        container.distribution = .fillEqually
        container.axis = .horizontal
        container.alignment = .fill
        container.backgroundColor = DcColors.systemMessageBackgroundColor
        return container
    }()

    private lazy var backgroundContainer: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        if let backgroundImageURL = UserDefaults.standard.string(forKey: Constants.Keys.backgroundImageUrl) {
            view.sd_setImage(with: URL(fileURLWithPath: backgroundImageURL), completed: nil)
        } else {
            setDefault(view)
        }

        return view
    }()

    private lazy var mediaPicker: MediaPicker = {
        let mediaPicker = MediaPicker(navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        setupSubviews()
    }

    private func setupSubviews() {
        view.addSubview(backgroundContainer)
        view.addSubview(container)

        view.addConstraints([
            container.constraintAlignBottomTo(view),
            container.constraintAlignLeadingTo(view),
            container.constraintAlignTrailingTo(view),
            backgroundContainer.constraintAlignBottomTo(view),
            backgroundContainer.constraintAlignLeadingTo(view),
            backgroundContainer.constraintAlignTrailingTo(view),
            backgroundContainer.constraintAlignTopTo(view)
        ])

        if #available(iOS 15, *) {
            self.navigationController?.navigationBar.isTranslucent = true
            self.navigationController?.toolbar.isTranslucent = true
            self.navigationController?.navigationBar.scrollEdgeAppearance = self.navigationController?.navigationBar.standardAppearance
        }
     }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bottomSafeArea = view.safeAreaInsets.bottom
        selectBackgroundButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 8, bottom: bottomSafeArea + 12, right: 8)
        selectDefaultButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 8, bottom: bottomSafeArea + 12, right: 8)
    }

    @objc private func onSelectBackgroundImage() {
        mediaPicker.showPhotoGallery()
    }

    @objc private func onDefaultSelected() {
        setDefault(backgroundContainer)
        UserDefaults.standard.set(nil, forKey: Constants.Keys.backgroundImageUrl)
        UserDefaults.standard.synchronize()
    }

    private func setDefault(_ imageView: UIImageView) {
        if #available(iOS 12.0, *) {
            imageView.image = UIImage(named: traitCollection.userInterfaceStyle == .light ? "background_light" : "background_dark")
        } else {
            imageView.image = UIImage(named: "background_light")
        }
    }

    // MARK: MediaPickerDelegate
    func onImageSelected(image: UIImage) {
        if let pathInDocDir = ImageFormat.saveImage(image: image) {
            UserDefaults.standard.set(pathInDocDir, forKey: Constants.Keys.backgroundImageUrl)
            UserDefaults.standard.synchronize()
            backgroundContainer.image = image
        }
    }
}

import Foundation
import UIKit
import DcCore

class SettingsBackgroundSelectionController: UIViewController {
    let dcContext: DcContext

    lazy var selectBackgroundButton: DynamicFontButton = {
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
        return btn
    }()

    lazy var selectDefaultButton: DynamicFontButton = {
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
        //btn.addTarget(self, action: #selector(onActionButtonTapped), for: .touchUpInside)
        btn.titleLabel?.font = UIFont.preferredFont(for: .body, weight: .regular)
        btn.titleLabel?.adjustsFontForContentSizeCategory = true
        return btn
    }()

    lazy var container: UIStackView = {
        let container = UIStackView(arrangedSubviews: [selectDefaultButton, selectBackgroundButton])
        container.translatesAutoresizingMaskIntoConstraints = false
        container.distribution = .fillEqually
        container.axis = .horizontal
        container.alignment = .fill
        container.backgroundColor = DcColors.systemMessageBackgroundColor
        return container
    }()

    public lazy var backgroundContainer: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 12.0, *) {
            view.image = UIImage(named: traitCollection.userInterfaceStyle == .light ? "background_light" : "background_dark")
        } else {
            view.image = UIImage(named: "background_light")
        }
        return view
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

    func setupSubviews() {
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

}

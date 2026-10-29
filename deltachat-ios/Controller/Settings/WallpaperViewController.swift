import Foundation
import UIKit
import DcCore
import SDWebImageSwiftUI
import SwiftUI

class WallpaperViewController: UIViewController, MediaPickerDelegate {
    var dcContext: DcContext

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        title = String.localized("pref_background")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: WallpaperView(vc: self))
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        host.view.fillSuperview()
    }

    func onImageSelected(image: UIImage) {
        if let path = ImageFormat.saveImage(image: image, name: Constants.backgroundImageName) {
            UserDefaults.standard.set(URL(fileURLWithPath: path).lastPathComponent, forKey: Constants.Keys.backgroundImageName)
        } else {
            logger.error("failed to save background image")
        }
    }
}

struct WallpaperView: View {
    weak var vc: WallpaperViewController?
    @State private var backgroundImageName = UserDefaults.standard.string(forKey: Constants.Keys.backgroundImageName)

    var body: some View {
        backgroundImageView
            .scaledToFill()
            .ignoresSafeArea(isLiquidGlassEnabled ? .all : [])
            .overlay(alignment: .bottom) {
                HStack {
                    Button(String.localized("pref_background_btn_default"), action: {
                        UserDefaults.standard.set(nil, forKey: Constants.Keys.backgroundImageName)
                    })
                    Button(String.localized("pref_background_btn_gallery"), action: {
                        guard let vc else { return }
                        let mediaPicker = MediaPicker(dcContext: vc.dcContext, navigationController: vc.navigationController)
                        mediaPicker.delegate = vc
                        mediaPicker.showGallery(allowCropping: true)
                    })
                }
                .frame(maxWidth: .infinity)
                .padding()
                .modifier { view in
                    if #available(iOS 26.0, *) {
                        GlassEffectContainer(spacing: 0) {
                            view.buttonStyle(.glass)
                        }
                    } else {
                        view.background(Material.bar, ignoresSafeAreaEdges: .bottom)
                            .overlay(alignment: .top, content: Divider.init)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                backgroundImageName = UserDefaults.standard.string(forKey: Constants.Keys.backgroundImageName)
            }
    }

    @ViewBuilder var backgroundImageView: some View {
        if let backgroundImageName {
            WebImage(url: Utils.getBackgroundImageURL(name: backgroundImageName))
                .resizable()
        } else {
            Image(vc?.traitCollection.userInterfaceStyle == .light ? "background_light" : "background_dark")
                .resizable()
        }
    }
}

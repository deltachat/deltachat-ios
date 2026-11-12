import Foundation
import UIKit
import DcCore
import SDWebImageSwiftUI
import SwiftUI

class WallpaperViewController: UIViewController, MediaPickerDelegate {
    var dcContext: DcContext
    lazy var mediaPicker = MediaPicker(dcContext: dcContext, navigationController: navigationController)

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
        navigationItem.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        super.viewDidLoad()
        let host = UIHostingController(rootView: WallpaperView(vc: self))
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        host.view.fillSuperview()
        view.clipsToBounds = true
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
        VStack {
            Spacer()
            VStack(spacing: 15) {
                if backgroundImageName != nil {
                    Button(String.localized("pref_background_btn_default"), action: {
                        UserDefaults.standard.set(nil, forKey: Constants.Keys.backgroundImageName)
                    })
                }
                Button(String.localized("pref_background_btn_gallery"), action: {
                    vc?.mediaPicker.delegate = vc
                    vc?.mediaPicker.showGallery(allowCropping: true)
                })
            }.modifier { view in
                if #available(iOS 26.0, *) {
                    GlassEffectContainer {
                        view.buttonStyle(.glass)
                    }
                } else {
                    view.buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .lineLimit(nil)
        .padding()
        .padding(.horizontal)
        .background {
            backgroundImageView.scaledToFill().ignoresSafeArea(.all)
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            backgroundImageName = UserDefaults.standard.string(forKey: Constants.Keys.backgroundImageName)
        }
    }

    @ViewBuilder var backgroundImageView: some View {
        if let backgroundImageName {
            WebImage(url: Utils.getBackgroundImageURL(name: backgroundImageName), options: .refreshCached)
                .resizable()
        } else {
            Image(vc?.traitCollection.userInterfaceStyle == .light ? "background_light" : "background_dark")
                .resizable()
        }
    }
}

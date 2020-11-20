import AVKit
import AVFoundation
import SDWebImage
import DcCore

// TODO: probably not able to trigger touch events this way
// MARK: - ContextMenuDelegate
protocol ContextMenuDelegate: class {
    func contextMenu(_: ContextMenuController, event: ContextMenuController.Event)
}

// MARK: - ContextMenuController
class ContextMenuController: UIViewController {

    let item: GalleryItem
    weak var delegate: ContextMenuDelegate?

    init(item: GalleryItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        let viewType = item.msg.viewtype
        var thumbnailView: UIView?
        switch viewType {
        case .image:
            thumbnailView = makeImageView(image: item.msg.image)
        case .video:
            thumbnailView = makeVideoView(videoUrl: item.msg.fileURL)
        case .gif:
            thumbnailView = makeGifView(gifImage: item.thumbnailImage)
        default:
            return
        }

        guard let contentView = thumbnailView else {
            return
        }

        let hitTestView = HitTestView()

        view.addSubview(hitTestView)
        view.addSubview(contentView)
        hitTestView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hitTestView.leftAnchor.constraint(equalTo: view.leftAnchor),
            hitTestView.rightAnchor.constraint(equalTo: view.rightAnchor),
            hitTestView.topAnchor.constraint(equalTo: view.topAnchor),
            hitTestView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.leftAnchor.constraint(equalTo: view.leftAnchor),
            contentView.rightAnchor.constraint(equalTo: view.rightAnchor),
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let button = UIButton(frame: CGRect(x: view.frame.midX, y: view.frame.midY, width: 100, height: 100))
        button.makeBorder()
        button.setTitle("Tap me", for: .normal)
        button.addTarget(self, action: #selector(handleThumbnailTap(_:)), for: .touchUpInside)
        view.addSubview(button)
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleThumbnailTap(_:)))
//        contentView.addGestureRecognizer(tapGesture)
//        contentView.makeBorder()
    }

    // MARK: - thumbnailView creation
    private func makeGifView(gifImage: UIImage?) -> UIView? {
        let view = SDAnimatedImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = DcColors.defaultBackgroundColor
        if let image = gifImage {
            setPreferredContentSize(for: image)
        }
        view.image = gifImage
        return view
    }

    private func makeImageView(image: UIImage?) -> UIView? {
        guard let image = image else {
            safe_fatalError("unexpected nil value")
            return nil
        }

        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.image = image
        setPreferredContentSize(for: image)
        return imageView
    }

    private func makeVideoView(videoUrl: URL?) -> UIView? {
        guard let videoUrl = videoUrl, let videoSize = item.thumbnailImage?.size else { return nil }
        let player = AVPlayer(url: videoUrl)
        let playerController = AVPlayerViewController()
        addChild(playerController)
        view.addSubview(playerController.view)
        playerController.didMove(toParent: self)
        playerController.view.backgroundColor = .darkGray
        playerController.view.clipsToBounds = true
        player.play()
        playerController.player = player

        // truncate edges on top/bottom or sides
        let resizedHeightFactor = view.frame.height / videoSize.height
        let resizedWidthFactor = view.frame.width / videoSize.width
        let effectiveResizeFactor = min(resizedWidthFactor, resizedHeightFactor)
        let maxHeight = videoSize.height * effectiveResizeFactor
        let maxWidth = videoSize.width * effectiveResizeFactor
        let size = CGSize(width: maxWidth, height: maxHeight)
        preferredContentSize = size

        return playerController.view
    }

    private func setPreferredContentSize(for image: UIImage) {
        let width = view.bounds.width
        let height = image.size.height * (width / image.size.width)
        self.preferredContentSize = CGSize(width: width, height: height)
    }

    // MARK: - actions
    @objc private func handleThumbnailTap(_ tapGesture: UITapGestureRecognizer) {
        delegate?.contextMenu(self, event: .tap(item))
    }


}

// MARK: - inner class definitions
extension ContextMenuController {
    enum Event {
        case tap(GalleryItem)
        case doupleTap(GalleryItem)
        case longPress(GalleryItem)
        // add event types if needed
    }
}


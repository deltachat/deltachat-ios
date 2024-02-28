import AVKit
import AVFoundation
import SDWebImage
import DcCore

// MARK: - ContextMenuController
class ContextMenuController: UIViewController {

    let msg: DcMsg
    let image: UIImage?

    init(msg: DcMsg, image: UIImage?) {
        self.msg = msg
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        let viewType = msg.type
        var thumbnailView: UIView?
        switch viewType {
        case DC_MSG_IMAGE, DC_MSG_STICKER:
            thumbnailView = makeImageView()
        case DC_MSG_VIDEO:
            thumbnailView = makeVideoView()
        case DC_MSG_GIF:
            thumbnailView = makeGifView()
        default:
            return
        }

        guard let contentView = thumbnailView else {
            return
        }

        view.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentView.leftAnchor.constraint(equalTo: view.leftAnchor),
            contentView.rightAnchor.constraint(equalTo: view.rightAnchor),
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - thumbnailView creation
    private func makeGifView() -> UIView? {
        let view = SDAnimatedImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = DcColors.defaultBackgroundColor
        if let image = image {
            setPreferredContentSize(for: image)
        }
        view.image = image
        return view
    }

    private func makeImageView() -> UIView? {
        guard let image = image else {
            return nil
        }

        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.image = image
        setPreferredContentSize(for: image)
        return imageView
    }

    private func makeVideoView() -> UIView? {
        guard let videoUrl = msg.fileURL, let videoSize = image?.size else { return nil }
        let player = AVPlayer(url: videoUrl)
        let playerController = AVPlayerViewController()
        addChild(playerController)
        view.addSubview(playerController.view)
        playerController.didMove(toParent: self)
        playerController.view.backgroundColor = .darkGray
        playerController.view.clipsToBounds = true
        playerController.player = player
        playerController.showsPlaybackControls = false
        player.play()

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
}

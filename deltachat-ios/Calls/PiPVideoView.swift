import UIKit
import DcCore
import AVKit
import WebRTC

class PiPVideoView: UIView {
    private var fromChat: DcChat

    /// Container view in which the video renderer view is placed when not in PiP
    private lazy var videoCallSourceView = UIView()
    /// We need to change the source view's height to have a good looking transition to and from PiP
    private lazy var videoCallSourceViewHeightConstraint: NSLayoutConstraint = {
        videoCallSourceView.heightAnchor.constraint(equalToConstant: frame.height)
    }()

    /// The view that is shown in the picture in picture window
    private lazy var pipView = UIView()

    /// The view that renders the video
    /// Note: Do not add subviews as this view may be rotated if the video source was rotated
    private lazy var renderView = {
        let renderView = PiPVideoRendererView(frame: frame)
        return renderView
    }()

    private lazy var avatarView: UIView = {
        let avatarView = InitialsBadge(size: 200)
        avatarView.setName(fromChat.name)
        avatarView.setColor(fromChat.color)
        avatarView.setImage(fromChat.profileImage)
        // Original InitialsBadge does not scale so convert to image
        let imageView = UIImageView(image: avatarView.asImage())
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    /// - Note: Returns nil on iOS 14
    lazy var pipController: AVPictureInPictureController? = {
        guard #available(iOS 15.0, *) else { return nil }
        let pipController = AVPictureInPictureController(contentSource: .init(
            activeVideoCallSourceView: videoCallSourceView,
            contentViewController: AVPictureInPictureVideoCallViewController()
        ))
        pipController.canStartPictureInPictureAutomaticallyFromInline = true
        return pipController
    }()

    init(fromChat: DcChat, frame: CGRect) {
        self.fromChat = fromChat
        super.init(frame: frame)

        addSubview(videoCallSourceView)
        videoCallSourceView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            videoCallSourceView.centerXAnchor.constraint(equalTo: centerXAnchor),
            videoCallSourceView.centerYAnchor.constraint(equalTo: centerYAnchor),
            videoCallSourceView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1.0),
            videoCallSourceViewHeightConstraint,
        ])

        pipView.addSubview(renderView)
        renderView.fillSuperview()
        pipView.addSubview(avatarView)
        avatarView.centerInSuperview()
        NSLayoutConstraint.activate([
            avatarView.leftAnchor.constraint(equalTo: pipView.leftAnchor, constant: 20),
            avatarView.topAnchor.constraint(equalTo: pipView.topAnchor, constant: 20),
        ], withPriority: .init(UILayoutPriority.required.rawValue - 1))
        avatarView.widthAnchor.constraint(lessThanOrEqualToConstant: 200).isActive = true

        videoCallSourceView.addSubview(pipView)
        pipView.fillSuperview()

        pipController?.delegate = self
        resetSize()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PiPVideoView: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        guard #available(iOS 15.0, *) else { return }
        let pipVC = pictureInPictureController.contentSource?.activeVideoCallContentViewController
        pipView.removeFromSuperview()
        pipVC?.view.addSubview(pipView)
        pipView.fillSuperview()
    }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        CallWindow.shared?.showCallUI()
        completionHandler(true)
    }
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipView.removeFromSuperview()
        videoCallSourceView.addSubview(pipView)
        pipView.fillSuperview()
        videoCallSourceView.setNeedsLayout()
    }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: any Error) {
        CallWindow.shared?.showCallUI()
    }
}

extension PiPVideoView: RTCVideoRenderer {
    /// Reset to a square
    func resetSize() {
        setSize(CGSize(width: frame.size.width, height: frame.size.width))
    }

    func setSize(_ size: CGSize) {
        renderView.frameProcessor?.setSize(size)
        DispatchQueue.main.async { [self] in
            setPiPPreferredContentSize(size)
            videoCallSourceViewHeightConstraint.constant = frame.width / size.width * size.height
            videoCallSourceView.setNeedsLayout()
        }
    }
    
    func renderFrame(_ frame: RTCVideoFrame?) {
        renderView.frameProcessor?.renderFrame(frame)
    }

    private func setPiPPreferredContentSize(_ size: CGSize) {
        guard #available(iOS 15.0, *) else { return }
        pipController?.contentSource?.activeVideoCallContentViewController.preferredContentSize = size
    }

    func updateVideoEnabled(_ videoEnabled: Bool) {
        avatarView.isHidden = videoEnabled
        if !videoEnabled {
            renderView.displayLayer?.flushAndRemoveImage()
            resetSize()
        }
    }
}

/// A view that can render an RTCVideoTrack in PiP using AVSampleBufferDisplayLayer.
/// This is required because MTKViews are not supported in PiP before iOS 18.
private class PiPVideoRendererView: UIView {
    fileprivate var frameProcessor: PiPFrameProcessor?
    fileprivate var displayLayer: AVSampleBufferDisplayLayer?

    override class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = true

        displayLayer = layer as? AVSampleBufferDisplayLayer
        guard let displayLayer else { return }
        displayLayer.videoGravity = .resizeAspectFill
        displayLayer.backgroundColor = UIColor.clear.cgColor
        displayLayer.flushAndRemoveImage()
        displayLayer.preventsDisplaySleepDuringVideoPlayback = true

        // Create frame processor immediately
        frameProcessor = PiPFrameProcessor(displayLayer: displayLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        displayLayer?.frame = bounds
    }
}

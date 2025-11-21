import UIKit
import DcCore
import AVKit
import WebRTC

class PiPVideoView: UIView {
    private var fromChat: DcChat

    /// Container view in which the video renderer view is placed when not in PiP
    private lazy var videoCallSourceView = UIView()
    private lazy var videoCallSourceViewHeightConstraint: NSLayoutConstraint = {
        videoCallSourceView.heightAnchor.constraint(equalToConstant: frame.height)
    }()

    /// The view that renders in the picture in picture window
    private lazy var pipRenderView = {
        let pipRenderView = PiPVideoRendererView(frame: frame)
        return pipRenderView
    }()

    private lazy var avatarView: InitialsBadge = {
        let avatarView = InitialsBadge(size: 200)
        avatarView.setName(fromChat.name)
        avatarView.setColor(fromChat.color)
        if let profileImage = fromChat.profileImage {
            avatarView.setImage(profileImage)
        }
        return avatarView
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

        videoCallSourceView.addSubview(avatarView)
        avatarView.centerInSuperview()

        videoCallSourceView.addSubview(pipRenderView)
        pipRenderView.fillSuperview()

        pipController?.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PiPVideoView: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        guard #available(iOS 15.0, *) else { return }
        let pipVC = pictureInPictureController.contentSource?.activeVideoCallContentViewController
        pipRenderView.removeFromSuperview()
        pipVC?.view.addSubview(pipRenderView)
        pipRenderView.fillSuperview()
    }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        CallWindow.shared?.showCallUI()
        completionHandler(true)
    }
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipRenderView.removeFromSuperview()
        videoCallSourceView.addSubview(pipRenderView)
        pipRenderView.fillSuperview()
    }
}

extension PiPVideoView: RTCVideoRenderer {
    func setSize(_ size: CGSize) {
        pipRenderView.frameProcessor?.setSize(size)
        setPiPPreferredContentSize(size)
        DispatchQueue.main.async { [self] in
            videoCallSourceViewHeightConstraint.constant = frame.width / size.width * size.height
            videoCallSourceView.setNeedsLayout()
        }
    }
    
    func renderFrame(_ frame: RTCVideoFrame?) {
        avatarView.isHidden = true
        pipRenderView.frameProcessor?.renderFrame(frame)
    }

    private func setPiPPreferredContentSize(_ size: CGSize) {
        guard #available(iOS 15.0, *) else { return }
        pipController?.contentSource?.activeVideoCallContentViewController.preferredContentSize = size
    }
}

/// A view that can render an RTCVideoTrack in PiP using AVSampleBufferDisplayLayer.
/// This is required because MTKViews are not supported in PiP before iOS 18.
private class PiPVideoRendererView: UIView {
    fileprivate var frameProcessor: PiPFrameProcessor?
    private var displayLayer: AVSampleBufferDisplayLayer?
    
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

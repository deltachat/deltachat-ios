import DcCore
import UIKit
import WebRTC

// TODO: "Connecting..." and "Ringing..." status messages
// TODO: Minimize call to PiP when app is opened from a deeplink (or from a notification)
// TODO: Fix missed call logic: if the missed call was from me dont send notification
// TODO: Actually stop capturing mic when muted
// TODO: Integrate with CallKit again

class CallViewController: UIViewController {
    var call: DcCall
    private lazy var factory = RTCPeerConnectionFactory()
    private var peerConnection: RTCPeerConnection?
    private var iceTricklingDataChannel: RTCDataChannel?
    /// Stores local ICE candidates to be sent to the remote peer when the data channel opens.
    private var iceTricklingBuffer: [RTCIceCandidate] = []
    @Published private var gatheredEnoughIce = false
    private let rtcAudioSession = RTCAudioSession.sharedInstance()
    private var localAudioTrack: RTCAudioTrack?
    private var localVideoCapturer: RTCCameraVideoCapturer?
    private var localVideoTrack: RTCVideoTrack?
    private lazy var localVideoView: RTCMTLVideoView = {
        let videoView = RTCMTLVideoView(frame: .zero)
        videoView.videoContentMode = .scaleAspectFill
        videoView.layer.cornerRadius = 20
        videoView.layer.cornerCurve = .continuous
        videoView.layer.masksToBounds = true
        return videoView
    }()
    private lazy var localVideoContainerView: UIView = {
        let shadowView = UIView()
        shadowView.layer.cornerRadius = 20
        shadowView.layer.cornerCurve = .continuous
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOffset = CGSize(width: 4, height: 4)
        shadowView.layer.shadowOpacity = 0.2
        shadowView.layer.shadowRadius = 5.0
        shadowView.isHidden = !call.hasVideoInitially
        return shadowView
    }()
    private var remoteVideoTrack: RTCVideoTrack?
    private lazy var remoteVideoView: PiPVideoView = {
        let dcContext = DcAccounts.shared.get(id: call.contextId)
        let dcChat = dcContext.getChat(chatId: call.chatId)
        return PiPVideoView(fromChat: dcChat, frame: view.frame)
    }()

    private lazy var hangupButton: UIButton = {
        let hangupButton = CallUIToggleButton(imageSystemName: "phone.down.fill", state: false)
        hangupButton.backgroundColor = .red
        hangupButton.tintColor = .white
        hangupButton.addTarget(self, action: #selector(hangup), for: .touchUpInside)
        return hangupButton
    }()

    private lazy var toggleMicrophoneButton: UIButton = {
        let toggleMicrophoneButton = CallUIToggleButton(imageSystemName: "mic.fill", state: true)
        toggleMicrophoneButton.addAction(UIAction { [unowned self, unowned toggleMicrophoneButton] _ in
            toggleMicrophoneButton.toggleState.toggle()
            localAudioTrack?.isEnabled.toggle()
        }, for: .touchUpInside)
        return toggleMicrophoneButton
    }()

    private lazy var toggleVideoButton: UIButton = {
        let toggleVideoButton = CallUIToggleButton(imageSystemName: "video.fill", state: localVideoTrack?.isEnabled == true)
        toggleVideoButton.addAction(UIAction { [unowned self, unowned toggleVideoButton] _ in
            toggleVideoButton.toggleState.toggle()
            localVideoTrack?.isEnabled.toggle()
            localVideoContainerView.isHidden.toggle()
            flipCameraButton.isHidden = !toggleVideoButton.toggleState
            let transceiver = peerConnection?.transceivers.first { $0.mediaType == .video }
            transceiver?.sender.track = toggleVideoButton.toggleState ? localVideoTrack : nil
            if toggleVideoButton.toggleState {
                localVideoCapturer?.startCapture(facing: .front)
            } else {
                localVideoCapturer?.stopCapture()
            }
        }, for: .touchUpInside)
        return toggleVideoButton
    }()

    private lazy var startPiPButton: UIButton = {
        let startPiPButton = CallUIToggleButton(imageSystemName: "pip.enter", state: false)
        startPiPButton.addAction(UIAction { [unowned self] _ in
            guard remoteVideoView.pipController?.isPictureInPictureActive != true else { return }
            remoteVideoView.pipController?.startPictureInPicture()
            CallWindow.shared?.hideCallUI()
        }, for: .touchUpInside)
        return startPiPButton
    }()

    private lazy var callButtonStackView: UIStackView = {
        let callButtonStackView = UIStackView(arrangedSubviews: [
            hangupButton,
            toggleMicrophoneButton,
            toggleVideoButton,
            remoteVideoView.pipController != nil ? startPiPButton : nil,
        ].compactMap(\.self))
        callButtonStackView.axis = .horizontal
        callButtonStackView.spacing = 16
        callButtonStackView.distribution = .fill
        callButtonStackView.contentMode = .center
        return callButtonStackView
    }()

    private lazy var unreadMessageCounter: MessageCounter = {
        let unreadMessageCounter = MessageCounter(count: 0, size: 30)
        unreadMessageCounter.backgroundColor = DcColors.unreadBadge
        unreadMessageCounter.isHidden = true
        unreadMessageCounter.isAccessibilityElement = false
        unreadMessageCounter.isUserInteractionEnabled = false
        return unreadMessageCounter
    }()

    private lazy var flipCameraButton: UIButton = {
        let flipCameraButton = CallUIToggleButton(imageSystemName: "camera.rotate.fill", size: 40, state: false)
        flipCameraButton.addAction(UIAction { [unowned self] _ in
            if let currentlyFacing = localVideoCapturer?.captureSession.inputs
                .compactMap({ $0 as? AVCaptureDeviceInput }).first?.device.position {
                localVideoCapturer?.startCapture(facing: currentlyFacing == .front ? .back : .front)
            }
        }, for: .touchUpInside)
        flipCameraButton.isHidden = !call.hasVideoInitially
        return flipCameraButton
    }()

    init(call: DcCall) {
        self.call = call
        super.init(nibName: nil, bundle: nil)

        #if DEBUG
        RTCSetMinDebugLogLevel(.warning)
        #endif
        RTCInitializeSSL()

        let config = RTCConfiguration()
        config.iceTransportPolicy = .all
        config.bundlePolicy = .maxBundle
        config.iceCandidatePoolSize = 1

        // If we set ice servers before creating peerconnection the factory can return nil
        config.iceServers = DcAccounts.shared.get(id: call.contextId).iceServers().map {
            RTCIceServer(urlStrings: $0.urls, username: $0.username, credential: $0.credential)
        }

        peerConnection = factory.peerConnection(with: config, constraints: .default, delegate: self)
        assert(peerConnection != nil)

        let iceTricklingConfig = RTCDataChannelConfiguration()
        iceTricklingConfig.isNegotiated = true
        iceTricklingConfig.channelId = 1
        iceTricklingDataChannel = peerConnection?.dataChannel(forLabel: "iceTrickling", configuration: iceTricklingConfig)
        iceTricklingDataChannel?.delegate = self
        assert(iceTricklingDataChannel != nil)

        NotificationCenter.default.addObserver(self, selector: #selector(handleOutgoingCallAcceptedEvent), name: Event.outgoingCallAccepted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        peerConnection?.close()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupStreams()
        configureAudioSession()

        view.backgroundColor = .black
        view.addSubview(remoteVideoView)
        remoteVideoView.fillSuperview()
        localVideoContainerView.addSubview(localVideoView)
        localVideoView.fillSuperview()
        view.addSubview(localVideoContainerView)
        localVideoContainerView.constraint(equalTo: CGSize(width: 150, height: 150))
        localVideoContainerView.alignTopToAnchor(view.safeAreaLayoutGuide.topAnchor, paddingTop: 10)
        localVideoContainerView.alignTrailingToAnchor(view.safeAreaLayoutGuide.trailingAnchor, paddingTrailing: 10)
        view.addSubview(flipCameraButton)
        flipCameraButton.alignBottomToAnchor(localVideoView.bottomAnchor, paddingBottom: 4)
        flipCameraButton.alignTrailingToAnchor(localVideoView.trailingAnchor, paddingTrailing: 4)
        view.addSubview(callButtonStackView)
        callButtonStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            callButtonStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            callButtonStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        view.addSubview(unreadMessageCounter)
        unreadMessageCounter.alignTrailingToAnchor(startPiPButton.trailingAnchor)
        unreadMessageCounter.alignTopToAnchor(startPiPButton.topAnchor)
        setUnreadMessageCount(DcAccounts.shared.getFreshMessagesCount())

        Task {
            guard let peerConnection else { return }
            switch call.direction {
            case .outgoing:
                do {
                    let offer = try await peerConnection.offer(for: RTCMediaConstraints.default)
                    try await peerConnection.setLocalDescription(offer)
                    if #available(iOS 15.0, *) {
                        _ = await $gatheredEnoughIce.values.first(where: \.self)
                    }
                    let sdp = peerConnection.localDescription?.sdp ?? offer.sdp
                    let dcContext = DcAccounts.shared.get(id: call.contextId)
                    call.messageId = dcContext.placeOutgoingCall(chatId: call.chatId, placeCallInfo: sdp)
                } catch {
                    logger.error(error.localizedDescription)
                }
            case .incoming:
                guard let placeCallInfo = call.placeCallInfo else {
                    logger.error("placeCallInfo missing for acceptCall")
                    // TODO: alert user?
                    CallManager.shared.endCallControllerAndHideUI()
                    return
                }
                try await peerConnection.setRemoteDescription(.init(type: .offer, sdp: placeCallInfo))
                let answer = try await peerConnection.answer(for: RTCMediaConstraints.default)
                try await peerConnection.setLocalDescription(answer)
                if #available(iOS 15.0, *) {
                    _ = await $gatheredEnoughIce.values.first(where: \.self)
                }
                guard let messageId = call.messageId else { return logger.error("errAcceptCall: messageId not set") }
                let sdp = peerConnection.localDescription?.sdp ?? answer.sdp
                logger.info("acceptCall: " + sdp)
                let dcContext = DcAccounts.shared.get(id: call.contextId)
                call.callAcceptedHere = true
                dcContext.acceptIncomingCall(msgId: messageId, acceptCallInfo: sdp)
            }
        }
    }

    private func setupStreams() {
        // Local audio
        let audioSource = factory.audioSource(with: RTCMediaConstraints.default)
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "localAudioTrack")
        localAudioTrack = audioTrack
        peerConnection?.add(audioTrack, streamIds: ["localStream"])

        // Local video
        let videoSource = factory.videoSource()
        localVideoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        let videoTrack = factory.videoTrack(with: videoSource, trackId: "localVideoTrack")
        if call.hasVideoInitially {
            localVideoCapturer?.startCapture(facing: .front)
            peerConnection?.add(videoTrack, streamIds: ["localStream"])
        } else {
            peerConnection?.addTransceiver(of: .video)
        }
        localVideoTrack = videoTrack
        localVideoTrack?.isEnabled = call.hasVideoInitially
        localVideoTrack?.add(localVideoView)
    }

    @objc private func hangup() {
        CallManager.shared.endCallControllerAndHideUI()
    }

    private func configureAudioSession() {
        rtcAudioSession.lockForConfiguration()
        do {
            try rtcAudioSession.setCategory(.playAndRecord)
            try rtcAudioSession.setMode(.videoChat)
        } catch {
            logger.error("Error updating AVAudioSession category: \(error)")
        }
        rtcAudioSession.unlockForConfiguration()
    }

    func setUnreadMessageCount(_ messageCount: Int) {
        unreadMessageCounter.setCount(messageCount)
        unreadMessageCounter.isHidden = messageCount == 0
    }

    // MARK: - Notifications

    @objc private func handleOutgoingCallAcceptedEvent(_ notification: Notification) {
        guard let ui = notification.userInfo,
              let accountId = ui["account_id"] as? Int,
              let msgId = ui["message_id"] as? Int,
              accountId == call.contextId && msgId == call.messageId,
              let acceptCallInfo = ui["accept_call_info"] as? String else { return }

        peerConnection?.setRemoteDescription(.init(type: .answer, sdp: acceptCallInfo)) { _ in }
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        // show call and end pip when returning to foreground
        CallWindow.shared?.showCallUI()
        if remoteVideoView.pipController?.isPictureInPictureActive == true {
            remoteVideoView.pipController?.stopPictureInPicture()
        }
    }
}

extension CallViewController: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        if newState == .complete {
            DispatchQueue.main.async { [weak self] in
                self?.gatheredEnoughIce = true
            }
        }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        // gatheredEnoughIce logic explained: https://github.com/deltachat/calls-webapp/blob/8b0069202db64c6d66a7fb56be70b457c61bf5a6/src/lib/calls.ts#L333
        DispatchQueue.main.async { [weak self] in
            guard let self, !gatheredEnoughIce else { return }
            if candidate.sdp.contains("typ relay") {
                gatheredEnoughIce = true
            } else if candidate.sdp.contains("typ srflx") {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(150)) { [weak self] in
                    self?.gatheredEnoughIce = true
                }
            }
        }
        if iceTricklingDataChannel?.readyState == .open {
            _ = try? iceTricklingDataChannel?.sendData(.init(data: candidate.toJSON(), isBinary: false))
        } else {
            iceTricklingBuffer.append(candidate)
        }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        switch dataChannel.label {
        case "iceTrickling":
            for candidate in iceTricklingBuffer {
                _ = try? dataChannel.sendData(.init(data: candidate.toJSON(), isBinary: true))
            }
        default: break
        }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
        if transceiver.mediaType == .video, let newTrack = transceiver.receiver.track as? RTCVideoTrack {
            remoteVideoTrack?.remove(remoteVideoView)
            remoteVideoTrack = newTrack
            remoteVideoTrack?.add(remoteVideoView)
        }
    }
}

extension CallViewController: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {}
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        switch dataChannel.label {
        case "iceTrickling":
            if let candidate = try? RTCIceCandidate.fromJSON(buffer.data) {
                peerConnection?.add(candidate, completionHandler: { _ in })
            }
        default: break
        }
    }
}

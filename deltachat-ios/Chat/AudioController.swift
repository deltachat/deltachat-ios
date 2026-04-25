import UIKit
import AVFoundation
import MediaPlayer
import DcCore

/// The `PlayerState` indicates the current audio controller state
public enum PlayerState {

    /// The audio controller is currently playing a sound
    case playing

    /// The audio controller is currently in pause state
    case pause

    /// The audio controller is not playing any sound and audioPlayer is nil
    case stopped
}

public protocol AudioControllerDelegate: AnyObject {
    func onAudioPlayFailed()
}

/// The `AudioController` update UI for current audio cell that is playing a sound
/// and also creates and manage an `AVAudioPlayer` states, play, pause and stop.
open class AudioController: NSObject, AVAudioPlayerDelegate, AudioMessageCellDelegate {

    private enum AudioPlaybackError: Error {
        case missingFileURL
        case playFailed
    }

    private static var backgroundPlaybackController: AudioController?
    private static var remoteCommandsConfigured = false

    open weak var delegate: AudioControllerDelegate?

    lazy var audioSession: AVAudioSession = {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.playback, options: [.defaultToSpeaker])
        } catch {
            logger.warning("setting audio session category failed: \(error.localizedDescription)")
        }
        return audioSession
    }()

    /// The `AVAudioPlayer` that is playing the sound
    open var audioPlayer: AVAudioPlayer?

    /// The `AudioMessageCell` that is currently playing sound
    open weak var playingCell: AudioMessageCell?

    /// The `MessageType` that is currently playing sound
    open var playingMessage: DcMsg?

    /// Specify if current audio controller state: playing, in pause or none
    open private(set) var state: PlayerState = .stopped

    private let dcContext: DcContext
    private let chatId: Int
    private let chat: DcChat

    /// The `Timer` that update playing progress
    internal var progressTimer: Timer?

    private var lastNowPlayingInfoUpdate = Date.distantPast
    private var playingArtwork: MPMediaItemArtwork?

    // MARK: - Init Methods

    public init(dcContext: DcContext, chatId: Int, delegate: AudioControllerDelegate? = nil) {
        self.dcContext = dcContext
        self.chatId = chatId
        self.chat = dcContext.getChat(chatId: chatId)
        self.delegate = delegate
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(audioRouteChanged),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appWillTerminate),
                                               name: UIApplication.willTerminateNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Methods

    static func stopBackgroundPlayback() {
        performOnMainAndWait {
            backgroundPlaybackController?.stopAnyOngoingPlaying()
        }
    }

    static func stopBackgroundPlayback(forContextId contextId: Int) {
        performOnMainAndWait {
            guard let controller = backgroundPlaybackController, controller.dcContext.id == contextId else { return }
            controller.stopAnyOngoingPlaying()
        }
    }

    /// - Parameters:
    ///   - cell: The `NewAudioMessageCell` that needs to be configure.
    ///   - message: The `DcMsg` that configures the cell.
    ///
    /// - Note:
    ///   This protocol method is called by MessageKit every time an audio cell needs to be configure
    func update(_ cell: AudioMessageCell, with messageId: Int) {
        cell.delegate = self
        if let activeController = AudioController.backgroundPlaybackController,
           activeController.isPlayingMessage(messageId: messageId, contextId: dcContext.id),
           let player = activeController.audioPlayer {
            activeController.playingCell = cell
            cell.audioPlayerView.setProgress((player.duration == 0) ? 0 : Float(player.currentTime/player.duration))
            cell.audioPlayerView.showPlayLayout(player.isPlaying)
            cell.audioPlayerView.setDuration(duration: player.currentTime)
        }
    }
    
    public func getAudioDuration(messageId: Int, successHandler: @escaping (Int, Double) -> Void) {
        let message = dcContext.getMessage(id: messageId)
        if AudioController.backgroundPlaybackController?.isPlayingMessage(messageId: messageId, contextId: dcContext.id) == true {
            // irgnore messages that are currently playing or recently paused
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let duration = message.duration
            if duration > 0 {
                DispatchQueue.main.async {
                    successHandler(messageId, Double(duration) / 1000)
                }
            } else if let fileURL = message.fileURL {
                let audioAsset = AVURLAsset.init(url: fileURL, options: nil)
                audioAsset.loadValuesAsynchronously(forKeys: ["duration"]) {
                    var error: NSError?
                    let status = audioAsset.statusOfValue(forKey: "duration", error: &error)
                    switch status {
                    case .loaded:
                        let duration = audioAsset.duration
                        let durationInSeconds = CMTimeGetSeconds(duration)
                        message.setLateFilingMediaSize(width: 0, height: 0, duration: Int(1000 * durationInSeconds))
                        DispatchQueue.main.async {
                            successHandler(messageId, Double(durationInSeconds))
                        }
                    case .failed:
                        logger.warning("loading audio message \(messageId) failed: \(String(describing: error?.localizedDescription))")
                    default: break
                    }
                }
            }
        }
    }

    public func playButtonTapped(cell: AudioMessageCell, messageId: Int) {
        let message = dcContext.getMessage(id: messageId)
        if let activeController = AudioController.backgroundPlaybackController, activeController !== self {
            if activeController.isPlayingMessage(messageId: message.id, contextId: dcContext.id) {
                activeController.playingCell = cell
                if activeController.state == .playing {
                    activeController.pauseSound(in: cell)
                } else {
                    activeController.resumeSound()
                }
                return
            }
            AudioController.stopBackgroundPlayback()
        }
        guard state != .stopped else {
            // There is no audio sound playing - prepare to start playing for given audio message
            playSound(for: message, in: cell)
            return
        }
        if isPlayingMessage(messageId: message.id, contextId: dcContext.id) {
            // tap occur in the current cell that is playing audio sound
            if state == .playing {
                pauseSound(in: cell)
            } else {
                resumeSound()
            }
        } else {
            // tap occur in a difference cell that the one is currently playing sound. First stop currently playing and start the sound for given message
            stopAnyOngoingPlaying()
            playSound(for: message, in: cell)
        }
    }

    /// Used to start play audio sound
    ///
    /// - Parameters:
    ///   - message: The `DcMsg` that contain the audio item to be played.
    ///   - audioCell: The `NewAudioMessageCell` that needs to be updated while audio is playing.
    open func playSound(for message: DcMsg, in audioCell: AudioMessageCell) {
        guard message.type == DC_MSG_AUDIO || message.type == DC_MSG_VOICE else { return }
        if let activeController = AudioController.backgroundPlaybackController, activeController !== self {
            AudioController.stopBackgroundPlayback()
        }
        do {
            guard let fileUrl = message.fileURL else { throw AudioPlaybackError.missingFileURL }
            let player = try AVAudioPlayer(contentsOf: fileUrl)
            try audioSession.setActive(true)
            audioPlayer = player
            playingCell = audioCell
            playingMessage = message
            loadArtwork(for: message)
            AudioController.backgroundPlaybackController = self
            AudioController.configureRemoteCommands()
            player.prepareToPlay()
            player.delegate = self
            state = .playing
            guard player.play() else {
                state = .stopped
                throw AudioPlaybackError.playFailed
            }
            audioCell.audioPlayerView.showPlayLayout(true)  // show pause button on audio cell
            updateNowPlayingInfo()
            startProgressTimer()
        } catch {
            logger.warning("playing audio message \(message.id) failed: \(error.localizedDescription)")
            stopAnyOngoingPlaying()
            delegate?.onAudioPlayFailed()
        }
    }

    /// Used to pause the audio sound
    ///
    /// - Parameters:
    ///   - message: The `MessageType` that contain the audio item to be pause.
    ///   - audioCell: The `AudioMessageCell` that needs to be updated by the pause action.
    open func pauseSound(in audioCell: AudioMessageCell? = nil) {
        guard let player = audioPlayer else { return }
        player.pause()
        state = .pause
        (audioCell ?? playingCell)?.audioPlayerView.showPlayLayout(false) // show play button on audio cell
        updateNowPlayingInfo()
        progressTimer?.invalidate()
    }

    /// Stops any ongoing audio playing if exists
    open func stopAnyOngoingPlaying() {
        guard let player = audioPlayer else { return }
        let duration = player.duration
        player.stop()
        state = .stopped
        if let cell = playingCell {
            cell.audioPlayerView.setProgress(0.0)
            cell.audioPlayerView.showPlayLayout(false)
            cell.audioPlayerView.setDuration(duration: duration)
        }
        progressTimer?.invalidate()
        progressTimer = nil
        audioPlayer = nil
        playingMessage = nil
        playingCell = nil
        playingArtwork = nil
        lastNowPlayingInfoUpdate = .distantPast
        if AudioController.backgroundPlaybackController === self {
            AudioController.backgroundPlaybackController = nil
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
        do {
            try audioSession.setActive(false)
        } catch {
            logger.warning("deactivating audio session failed: \(error.localizedDescription)")
        }
    }

    /// Resume a currently pause audio sound
    open func resumeSound() {
        guard let player = audioPlayer else {
            stopAnyOngoingPlaying()
            return
        }
        player.prepareToPlay()
        guard player.play() else {
            logger.warning("resuming audio playback failed")
            stopAnyOngoingPlaying()
            delegate?.onAudioPlayFailed()
            return
        }
        state = .playing
        updateNowPlayingInfo()
        startProgressTimer()
        playingCell?.audioPlayerView.showPlayLayout(true) // show pause button on audio cell
    }

    // MARK: - Fire Methods
    @objc private func didFireProgressTimer(_ timer: Timer) {
        guard let player = audioPlayer else {
            return
        }
        playingCell?.audioPlayerView.setProgress((player.duration == 0) ? 0 : Float(player.currentTime/player.duration))
        playingCell?.audioPlayerView.setDuration(duration: player.currentTime)
        updateNowPlayingInfoIfNeeded()
    }

    // MARK: - Private Methods
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
        let timer = Timer(timeInterval: 0.1,
                          target: self,
                          selector: #selector(AudioController.didFireProgressTimer(_:)),
                          userInfo: nil,
                          repeats: true)
        progressTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func isPlayingMessage(messageId: Int, contextId: Int) -> Bool {
        return dcContext.id == contextId && playingMessage?.id == messageId
    }

    private func updateNowPlayingInfoIfNeeded() {
        guard Date().timeIntervalSince(lastNowPlayingInfoUpdate) >= 1 else { return }
        updateNowPlayingInfo()
    }

    private func loadArtwork(for message: DcMsg) {
        playingArtwork = nil
        let contact = dcContext.getContact(id: message.fromContactId)
        guard let imageURL = contact.profileImageURL else {
            playingArtwork = nil
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self, messageId = message.id, contextId = self.dcContext.id] in
            guard let data = try? Data(contentsOf: imageURL), let image = UIImage(data: data) else { return }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            DispatchQueue.main.async {
                guard let self,
                      self.isPlayingMessage(messageId: messageId, contextId: contextId) else { return }
                self.playingArtwork = artwork
                self.updateNowPlayingInfo()
            }
        }
    }

    private static func configureRemoteCommands() {
        guard !remoteCommandsConfigured else { return }
        remoteCommandsConfigured = true
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { _ in
            return enqueueRemoteCommand { $0.resumeSound() }
        }
        commandCenter.pauseCommand.addTarget { _ in
            return enqueueRemoteCommand { $0.pauseSound() }
        }
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            return enqueueRemoteCommand { controller in
                if controller.state == .playing {
                    controller.pauseSound()
                } else {
                    controller.resumeSound()
                }
            }
        }
        commandCenter.stopCommand.addTarget { _ in
            return enqueueRemoteCommand { $0.stopAnyOngoingPlaying() }
        }
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .noActionableNowPlayingItem }
            return enqueueRemoteCommand { controller in
                guard let player = controller.audioPlayer else { return }
                player.currentTime = event.positionTime
                controller.updateNowPlayingInfo()
            }
        }
    }

    private static func enqueueRemoteCommand(_ action: @escaping (AudioController) -> Void) -> MPRemoteCommandHandlerStatus {
        guard let controller = backgroundPlaybackController else { return .noActionableNowPlayingItem }
        DispatchQueue.main.async { [weak controller] in
            guard let controller,
                  backgroundPlaybackController === controller else { return }
            action(controller)
        }
        return .success
    }

    private static func performOnMainAndWait(_ action: () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.sync(execute: action)
        }
    }

    private func updateNowPlayingInfo() {
        guard let player = audioPlayer, let message = playingMessage else { return }
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        if let text = message.text, !text.isEmpty {
            nowPlayingInfo[MPMediaItemPropertyTitle] = text
        } else {
            nowPlayingInfo[MPMediaItemPropertyTitle] = String.localized(message.type == DC_MSG_VOICE ? "voice_message" : "audio")
        }
        nowPlayingInfo[MPMediaItemPropertyArtist] = chat.name
        if let playingArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = playingArtwork
        } else {
            nowPlayingInfo.removeValue(forKey: MPMediaItemPropertyArtwork)
        }
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        lastNowPlayingInfoUpdate = Date()
    }

    // MARK: - AVAudioPlayerDelegate
    open func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopAnyOngoingPlaying()
    }

    open func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        stopAnyOngoingPlaying()
    }

    @objc private func appWillTerminate() {
        guard AudioController.backgroundPlaybackController === self else { return }
        stopAnyOngoingPlaying()
    }

    // MARK: - AVAudioSession.routeChangeNotification handler
    @objc func audioRouteChanged(note: Notification) {
        if let userInfo = note.userInfo,
           let reason = userInfo[AVAudioSessionRouteChangeReasonKey] as? Int,
           reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue,
           AudioController.backgroundPlaybackController === self {
            // headphones plugged out
            pauseSound()
        }
    }
}

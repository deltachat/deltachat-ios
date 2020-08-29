import UIKit
import AVFoundation
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

/// The `NewAudioController` update UI for current audio cell that is playing a sound
/// and also creates and manage an `AVAudioPlayer` states, play, pause and stop.
open class NewAudioController: NSObject, AVAudioPlayerDelegate, NewAudioMessageCellDelegate {

    lazy var audioSession: AVAudioSession = {
        let audioSession = AVAudioSession.sharedInstance()
        _ = try? audioSession.setCategory(AVAudioSession.Category.playback, options: [.defaultToSpeaker])
        return audioSession
    }()

    /// The `AVAudioPlayer` that is playing the sound
    open var audioPlayer: AVAudioPlayer?

    /// The `AudioMessageCell` that is currently playing sound
    open weak var playingCell: NewAudioMessageCell?

    /// The `MessageType` that is currently playing sound
    open var playingMessage: DcMsg?

    /// Specify if current audio controller state: playing, in pause or none
    open private(set) var state: PlayerState = .stopped

    private let dcContext: DcContext
    private let chatId: Int
    private let chat: DcChat

    /// The `Timer` that update playing progress
    internal var progressTimer: Timer?

    // MARK: - Init Methods

    public init(dcContext: DcContext, chatId: Int) {
        self.dcContext = dcContext
        self.chatId = chatId
        self.chat = dcContext.getChat(chatId: chatId)
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(audioRouteChanged),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: AVAudioSession.sharedInstance())
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Methods

    /// - Parameters:
    ///   - cell: The `NewAudioMessageCell` that needs to be configure.
    ///   - message: The `DcMsg` that configures the cell.
    ///
    /// - Note:
    ///   This protocol method is called by MessageKit every time an audio cell needs to be configure
    func update(_ cell: NewAudioMessageCell, with messageId: Int) {
        cell.delegate = self
        if playingMessage?.id == messageId, let player = audioPlayer {
            playingCell = cell
            cell.audioPlayerView.setProgress((player.duration == 0) ? 0 : Float(player.currentTime/player.duration))
            cell.audioPlayerView.showPlayLayout((player.isPlaying == true) ? true : false)
            cell.audioPlayerView.setDuration(duration: player.currentTime)
        }
    }

    public func playButtonTapped(cell: NewAudioMessageCell, messageId: Int) {
            let message = DcMsg(id: messageId)
            guard state != .stopped else {
                // There is no audio sound playing - prepare to start playing for given audio message
                playSound(for: message, in: cell)
                return
            }
            if playingMessage?.messageId == message.messageId {
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
    open func playSound(for message: DcMsg, in audioCell: NewAudioMessageCell) {
        if message.type == DC_MSG_AUDIO || message.type == DC_MSG_VOICE {
            _ = try? audioSession.setActive(true)
            playingCell = audioCell
            playingMessage = message
            if let fileUrl = message.fileURL, let player = try? AVAudioPlayer(contentsOf: fileUrl) {
                audioPlayer = player
                audioPlayer?.prepareToPlay()
                audioPlayer?.delegate = self
                audioPlayer?.play()
                state = .playing
                audioCell.audioPlayerView.showPlayLayout(true)  // show pause button on audio cell
                startProgressTimer()
            }

            print("NewAudioController failed play sound becasue given message kind is not Audio")
        }
    }

    /// Used to pause the audio sound
    ///
    /// - Parameters:
    ///   - message: The `MessageType` that contain the audio item to be pause.
    ///   - audioCell: The `AudioMessageCell` that needs to be updated by the pause action.
    open func pauseSound(in audioCell: NewAudioMessageCell) {
        audioPlayer?.pause()
        state = .pause
        audioCell.audioPlayerView.showPlayLayout(false) // show play button on audio cell
        progressTimer?.invalidate()
    }

    /// Stops any ongoing audio playing if exists
    open func stopAnyOngoingPlaying() {
        // If the audio player is nil then we don't need to go through the stopping logic
        guard let player = audioPlayer else { return }
        player.stop()
        state = .stopped
        if let cell = playingCell {
            cell.audioPlayerView.setProgress(0.0)
            cell.audioPlayerView.showPlayLayout(false)
            cell.audioPlayerView.setDuration(duration: player.duration)
        }
        progressTimer?.invalidate()
        progressTimer = nil
        audioPlayer = nil
        playingMessage = nil
        playingCell = nil
        try? audioSession.setActive(false)
    }

    /// Resume a currently pause audio sound
    open func resumeSound() {
        guard let player = audioPlayer, let cell = playingCell else {
            stopAnyOngoingPlaying()
            return
        }
        player.prepareToPlay()
        player.play()
        state = .playing
        startProgressTimer()
        cell.audioPlayerView.showPlayLayout(true) // show pause button on audio cell
    }

    // MARK: - Fire Methods
    @objc private func didFireProgressTimer(_ timer: Timer) {
        guard let player = audioPlayer, let cell = playingCell else {
            return
        }
        cell.audioPlayerView.setProgress((player.duration == 0) ? 0 : Float(player.currentTime/player.duration))
        cell.audioPlayerView.setDuration(duration: player.currentTime)
    }

    // MARK: - Private Methods
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
        progressTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                             target: self,
                                             selector: #selector(NewAudioController.didFireProgressTimer(_:)),
                                             userInfo: nil,
                                             repeats: true)
    }

    // MARK: - AVAudioPlayerDelegate
    open func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopAnyOngoingPlaying()
    }

    open func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        stopAnyOngoingPlaying()
    }

    // MARK: - AVAudioSession.routeChangeNotification handler
    @objc func audioRouteChanged(note: Notification) {
      if let userInfo = note.userInfo {
        if let reason = userInfo[AVAudioSessionRouteChangeReasonKey] as? Int {
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
            // headphones plugged out
            resumeSound()
          }
        }
      }
    }
}

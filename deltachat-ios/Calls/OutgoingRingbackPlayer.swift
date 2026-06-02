import AVFoundation

final class OutgoingRingbackPlayer {
    private lazy var player: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "outgoing-ringback", withExtension: "caf", subdirectory: "Assets") else {
            assertionFailure("Missing resource")
            return nil
        }
        let player = try? AVAudioPlayer(contentsOf: url)
        assert(player != nil, "Failed to init AVAudioPlayer")
        player?.numberOfLoops = -1
        player?.prepareToPlay()
        return player
    }()
    private var ringbackWorkItem: DispatchWorkItem?

    deinit {
        stopPlayback()
    }

    func startOutgoingRingback(after delay: TimeInterval = 1.5) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.startOutgoingRingback(after: delay)
            }
            return
        }

        stop()

        let workItem = DispatchWorkItem { [weak self] in
            self?.playRingbackLoop()
        }
        ringbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func stop() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.stop()
            }
            return
        }

        stopPlayback()
    }

    private func playRingbackLoop() {
        do {
            let player = try makePlayer()
            guard !player.isPlaying else { return }
            player.play()
        } catch {
            logger.error("☎️ failed to start outgoing ringback: \(error.localizedDescription)")
            stop()
        }
    }

    private func makePlayer() throws -> AVAudioPlayer {
        if let player {
            return player
        }

        guard let url = Bundle.main.url(forResource: "outgoing-ringback", withExtension: "caf", subdirectory: "Assets") else {
            throw RingbackError.missingResource
        }

        let player = try AVAudioPlayer(contentsOf: url)
        player.numberOfLoops = -1
        player.prepareToPlay()
        self.player = player
        return player
    }

    private func stopPlayback() {
        ringbackWorkItem?.cancel()
        ringbackWorkItem = nil

        player?.stop()
        player?.currentTime = 0
    }
}

private enum RingbackError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "Assets/outgoing-ringback.caf is missing from the app bundle"
        }
    }
}

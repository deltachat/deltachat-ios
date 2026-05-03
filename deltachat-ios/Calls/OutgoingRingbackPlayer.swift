import AVFoundation

final class OutgoingRingbackPlayer {
    static let shared = OutgoingRingbackPlayer()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var ringbackBuffer: AVAudioPCMBuffer?
    private var ringbackWorkItem: DispatchWorkItem?
    private var isEngineConfigured = false

    private init() {}

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

        ringbackWorkItem?.cancel()
        ringbackWorkItem = nil

        if player.isPlaying {
            player.stop()
        }

        if engine.isRunning {
            engine.stop()
        }
    }

    private func playRingbackLoop() {
        guard !player.isPlaying else { return }

        do {
            let buffer = makeRingbackBuffer()
            configureEngine(format: buffer.format)
            player.scheduleBuffer(buffer, at: nil, options: .loops)

            if !engine.isRunning {
                try engine.start()
            }

            player.play()
        } catch {
            logger.error("☎️ failed to start outgoing ringback: \(error.localizedDescription)")
            stop()
        }
    }

    private func configureEngine(format: AVAudioFormat) {
        guard !isEngineConfigured else { return }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        isEngineConfigured = true
    }

    private func makeRingbackBuffer() -> AVAudioPCMBuffer {
        if let ringbackBuffer {
            return ringbackBuffer
        }

        let sampleRate = 44_100.0
        let duration = 6.0
        let ringDuration = 2.0
        let fadeDuration = 0.02
        let amplitude = 0.16
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!

        buffer.frameLength = frameCount

        let samples = buffer.floatChannelData![0]
        for index in 0 ..< Int(frameCount) {
            let time = Double(index) / sampleRate
            let cycleTime = time.truncatingRemainder(dividingBy: duration)

            guard cycleTime < ringDuration else {
                samples[index] = 0
                continue
            }

            let fadeIn = min(cycleTime / fadeDuration, 1)
            let fadeOut = min((ringDuration - cycleTime) / fadeDuration, 1)
            let envelope = min(fadeIn, fadeOut)
            let tone = (sin(2 * .pi * 440 * time) + sin(2 * .pi * 480 * time)) * 0.5
            samples[index] = Float(amplitude * envelope * tone)
        }

        ringbackBuffer = buffer
        return buffer
    }
}

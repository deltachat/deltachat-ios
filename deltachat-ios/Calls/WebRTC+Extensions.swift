import WebRTC

extension RTCIceCandidate {
    static func fromJSON(_ data: Data) throws -> RTCIceCandidate {
        try JSONDecoder().decode(IceCandidate.self, from: data).rtc()
    }
    func toJSON() throws -> Data {
        try JSONEncoder().encode(IceCandidate(candidate: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid))
    }

    /// RTCIceCandidate+Codable
    private struct IceCandidate: Codable {
        /// candidate == RTCIceCandidate.sdp, https://chromium.googlesource.com/external/webrtc/+/branch-heads/53/webrtc/examples/objc/AppRTCDemo/RTCICECandidate+JSON.m#19
        let candidate: String
        let sdpMLineIndex: Int32
        let sdpMid: String?

        func rtc() -> RTCIceCandidate {
            .init(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        }
    }
}

extension RTCMediaConstraints {
    static var `default`: RTCMediaConstraints {
        RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
    }
}

extension AVCaptureDevice.Format {
    var maxFrameRate: Int {
        Int(videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0)
    }
}

extension RTCCameraVideoCapturer {
    func startCapture(facing: AVCaptureDevice.Position) {
        if let device = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == facing }),
           let format = reasonableFormat(for: device) {
            // Encoder complains about anything higher than 40fps on older devices
            startCapture(with: device, format: format, fps: min(format.maxFrameRate, 40))
        }
    }

    private func reasonableFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
        let highFpsFormats = formats.filter { $0.videoSupportedFrameRateRanges.contains { $0.maxFrameRate > 30 } }
        guard !highFpsFormats.isEmpty else { return formats.last }
        let noExtraHighResFormats = highFpsFormats.filter {
            // Larger formats cause issues with disabling/enabling camera on older devices
            $0.formatDescription.dimensions.width * $0.formatDescription.dimensions.height <= 1280 * 720
        }
        return noExtraHighResFormats.last ?? highFpsFormats.last
    }
}

import AVFoundation
import WebRTC

class PiPFrameProcessor: NSObject, RTCVideoRenderer {
    private weak var displayLayer: AVSampleBufferDisplayLayer?
    private let maxFrameRate: Int32 = 25
    private let processingQueue = DispatchQueue(label: "chat.delta.rtc.frame_processing", qos: .userInteractive)
    private var nextFrame: RTCVideoFrame?
    private var isProcessing = false
    private var rotation: RTCVideoRotation = ._0

    init(displayLayer: AVSampleBufferDisplayLayer) {
        super.init()
        self.displayLayer = displayLayer
    }
    
    func setSize(_ size: CGSize) {}

    func renderFrame(_ frame: RTCVideoFrame?) {
        processingQueue.async { [weak self] in
            self?.nextFrame = frame
            self?.processNextFrame()
        }
    }
    
    private func processNextFrame() {
        guard !isProcessing, let frame = nextFrame, let displayLayer else { return }
        isProcessing = true
        autoreleasepool {
            if let pixelBuffer = getPixelBuffer(from: frame),
               let sampleBuffer = createSampleBuffer(from: pixelBuffer) {
                DispatchQueue.main.async { [self] in
                    displayLayer.enqueue(sampleBuffer)
                    if rotation != frame.rotation {
                        rotation = frame.rotation
                        let angle = CGFloat(rotation.rawValue) * .pi / 180
                        displayLayer.transform = CATransform3DMakeAffineTransform(.init(rotationAngle: angle))
                    }
                }
                isProcessing = false
                if nextFrame !== frame {
                    processNextFrame()
                }
            } else {
                isProcessing = false
            }
        }
    }
    
    private func createSampleBuffer(from pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        // Use more precise timing
        var timing = CMSampleTimingInfo()
        timing.presentationTimeStamp = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 90000)
        timing.duration = CMTime(value: 1, timescale: Int32(maxFrameRate))
        timing.decodeTimeStamp = .invalid
        
        var formatDesc: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDesc
        )

        var sampleBuffer: CMSampleBuffer?
        if let formatDesc {
            CMSampleBufferCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                dataReady: true,
                makeDataReadyCallback: nil,
                refcon: nil,
                formatDescription: formatDesc,
                sampleTiming: &timing,
                sampleBufferOut: &sampleBuffer
            )
        }
        
        return sampleBuffer
    }
    
    private func getPixelBuffer(from frame: RTCVideoFrame) -> CVPixelBuffer? {
        if let cvBuffer = frame.buffer as? RTCCVPixelBuffer {
            return cvBuffer.pixelBuffer
        } else if let i420Buffer = frame.buffer as? RTCI420Buffer {
            return createPixelBuffer(from: i420Buffer, width: Int(frame.width), height: Int(frame.height))
        }
        return nil
    }
    
    private func createPixelBuffer(from i420Buffer: RTCI420Buffer, width: Int, height: Int) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ] as CFDictionary

        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs,
            &buffer
        )

        guard status == kCVReturnSuccess, let buffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])

        let yStride = Int(i420Buffer.strideY)
        let uStride = Int(i420Buffer.strideU)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let bgraBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        for row in 0..<height {
            for col in 0..<width {
                let yIndex = row * yStride + col
                let uvIndex = (row / 2) * uStride + (col / 2)
                
                let y = Int(i420Buffer.dataY[yIndex])
                let u = Int(i420Buffer.dataU[uvIndex]) - 128
                let v = Int(i420Buffer.dataV[uvIndex]) - 128

                // YUV to RGB conversion
                var r = (y * 298 + v * 409 + 128) >> 8
                var g = (y * 298 - u * 100 - v * 208 + 128) >> 8
                var b = (y * 298 + u * 516 + 128) >> 8
                
                // Clamp values
                r = max(0, min(255, r))
                g = max(0, min(255, g))
                b = max(0, min(255, b))
                
                let pixelOffset = row * bytesPerRow + col * 4
                
                // BGRA format
                bgraBuffer[pixelOffset + 0] = UInt8(b)     // B
                bgraBuffer[pixelOffset + 1] = UInt8(g)     // G
                bgraBuffer[pixelOffset + 2] = UInt8(r)     // R
                bgraBuffer[pixelOffset + 3] = 255          // A
            }
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
    
    deinit {
        displayLayer?.flushAndRemoveImage()
    }
}

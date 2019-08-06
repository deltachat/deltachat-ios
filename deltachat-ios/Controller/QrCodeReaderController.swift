import AVFoundation
import UIKit

class QrCodeReaderController: UIViewController {
    var captureSession = AVCaptureSession()

    var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    weak var delegate: QrCodeReaderDelegate?

    private let supportedCodeTypes = [
        AVMetadataObject.ObjectType.qr
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let captureDevice = AVCaptureDevice.DiscoverySession.init(
			deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
			mediaType: .video,
			position: .back).devices.first else {
				print("Failed to get the camera device")
				return
		}

        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(input)

            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession.addOutput(captureMetadataOutput)

            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            logger.error("failed to setup QR Code Scanner: \(error)")
            return
        }

        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(videoPreviewLayer!)

    }

	override func viewWillAppear(_ animated: Bool) {
		captureSession.startRunning()
	}
	override func viewWillDisappear(_ animated: Bool) {
		captureSession.stopRunning()
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension QrCodeReaderController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from _: AVCaptureConnection) {

        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject

        if supportedCodeTypes.contains(metadataObj.type) {
            if metadataObj.stringValue != nil {
				self.delegate?.handleQrCode(metadataObj.stringValue!)
            }
        }
    }
}

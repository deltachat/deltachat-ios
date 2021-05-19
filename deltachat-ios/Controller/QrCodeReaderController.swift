import AVFoundation
import UIKit
import DcCore

class QrCodeReaderController: UIViewController {

    weak var delegate: QrCodeReaderDelegate?

    private let captureSession = AVCaptureSession()
    
    private var infoLabelBottomConstraint: NSLayoutConstraint?
    private var infoLabelCenterConstraint: NSLayoutConstraint?

    private lazy var videoPreviewLayer: AVCaptureVideoPreviewLayer = {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        return videoPreviewLayer
    }()

    private var infoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String.localized("qrscan_hint")
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.adjustsFontForContentSizeCategory = true
        label.font = .preferredFont(forTextStyle: .subheadline)

        return label
    }()

    private let supportedCodeTypes = [
        AVMetadataObject.ObjectType.qr
    ]

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = []
        title = String.localized("qrscan_title")
        self.setupInfoLabel()
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            self.setupQRCodeScanner()
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: {  [weak self] (granted: Bool) in
                guard let self = self else { return }
                if granted {
                    self.setupQRCodeScanner()
                } else {
                    self.setInfoWarning(text: "You need to give Delta Chat the camera permission in order to use the QR-Code scanner")
                }
            })
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: nil, completion: { [weak self] _ in
            DispatchQueue.main.async(execute: {
                self?.updateVideoOrientation()
            })
        })
    }

    override func viewWillDisappear(_ animated: Bool) {
        stopSession()
    }

    // MARK: - setup
    
    private func setupQRCodeScanner() {
        guard let captureDevice = AVCaptureDevice.DiscoverySession.init(
            deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
            mediaType: .video,
            position: .back).devices.first else {
            self.setInfoWarning(text: "Failed to get the camera device. It might be occupied by another app.")
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            self.captureSession.addInput(input)

            let captureMetadataOutput = AVCaptureMetadataOutput()
            self.captureSession.addOutput(captureMetadataOutput)

            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = self.supportedCodeTypes
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            self.setInfoWarning(text: "failed to setup QR Code Scanner: \(error)")
            return
        }
        view.layer.addSublayer(videoPreviewLayer)
        videoPreviewLayer.frame = view.layer.bounds
    }
    
    private func setupInfoLabel() {
        view.addSubview(infoLabel)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabelBottomConstraint = infoLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        infoLabelCenterConstraint = infoLabel.constraintCenterYTo(view)
        infoLabelBottomConstraint?.isActive = true
        infoLabel.constraintAlignLeadingTo(view, paddingLeading: 5).isActive = true
        infoLabel.constraintAlignTrailingTo(view, paddingTrailing: 5).isActive = true
        view.bringSubviewToFront(infoLabel)
    }
    
    private func setInfoWarning(text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            logger.error(text)
            self.infoLabel.textColor = DcColors.defaultTextColor
            self.infoLabel.text = text
            self.infoLabelBottomConstraint?.isActive = false
            self.infoLabelCenterConstraint?.isActive = true
        }
    }
    
    private func updateVideoOrientation() {

        guard let connection = videoPreviewLayer.connection else {
            return
        }
        guard connection.isVideoOrientationSupported else {
            return
        }
        let statusBarOrientation = UIApplication.shared.statusBarOrientation
        let videoOrientation: AVCaptureVideoOrientation =  statusBarOrientation.videoOrientation ?? .portrait

        if connection.videoOrientation == videoOrientation {
            print("no change to videoOrientation")
            return
        }
        videoPreviewLayer.frame = view.bounds
        connection.videoOrientation = videoOrientation
        videoPreviewLayer.removeAllAnimations()
    }

    // MARK: - actions
    func startSession() {
        #if targetEnvironment(simulator)
        // ignore if run from simulator
        #else
        captureSession.startRunning()
        #endif
    }

     
    func stopSession() {
        captureSession.stopRunning()
    }
}

extension QrCodeReaderController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from _: AVCaptureConnection) {

        if let metadataObj = metadataObjects[0] as? AVMetadataMachineReadableCodeObject {
            if supportedCodeTypes.contains(metadataObj.type) {
                if metadataObj.stringValue != nil {
                    self.captureSession.stopRunning()
                    self.delegate?.handleQrCode(metadataObj.stringValue!)
                }
            }
        }
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeRight: return .landscapeRight
        case .landscapeLeft: return .landscapeLeft
        case .portrait: return .portrait
        default: return nil
        }
    }
}

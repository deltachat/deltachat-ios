import AVFoundation
import UIKit

class QrCodeReaderController: UIViewController {

    weak var delegate: QrCodeReaderDelegate?

    private let captureSession = AVCaptureSession()

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
           return label
    }()

    private lazy var closeButton: UIBarButtonItem = {
        return UIBarButtonItem(title: String.localized("cancel"), style: .done, target: self, action: #selector(closeButtonPressed(_:)))
    }()


    private let supportedCodeTypes = [
        AVMetadataObject.ObjectType.qr
    ]

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = []
        title = String.localized("qrscan_title")
        navigationItem.leftBarButtonItem = closeButton

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

        setupSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        captureSession.startRunning()
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
        captureSession.stopRunning()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - setup
    private func setupSubviews() {
        view.layer.addSublayer(videoPreviewLayer)
        videoPreviewLayer.frame = view.layer.bounds
        view.addSubview(infoLabel)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false

        infoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        infoLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0).isActive = true
        view.bringSubviewToFront(infoLabel)
    }

    func updateVideoOrientation() {

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
    @objc private func closeButtonPressed(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension QrCodeReaderController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from _: AVCaptureConnection) {

        if let metadataObj = metadataObjects[0] as? AVMetadataMachineReadableCodeObject {
            if supportedCodeTypes.contains(metadataObj.type) {
                if metadataObj.stringValue != nil {
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

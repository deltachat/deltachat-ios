import AVFoundation
import UIKit
import DcCore

class QrCodeReaderController: UIViewController {

    weak var delegate: QrCodeReaderDelegate?

    private lazy var captureSession = AVCaptureSession()

    private let addHints: String?
    private let showTroubleshooting: Bool
    private var infoLabelBottomConstraint: NSLayoutConstraint?
    private var infoLabelCenterConstraint: NSLayoutConstraint?

    private lazy var videoPreviewLayer: AVCaptureVideoPreviewLayer = {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        return videoPreviewLayer
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        return UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel, target: self, action: #selector(onCancelPressed))
    }()

    private lazy var moreButton: UIBarButtonItem = {
        let image = UIImage(systemName: "ellipsis.circle")
        return UIBarButtonItem(image: image, menu: moreButtonMenu())
    }()

    private lazy var infoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = addHints ?? String.localized("qrscan_hint")
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.adjustsFontForContentSizeCategory = true
        label.font = .preferredFont(forTextStyle: .title2)
        return label
    }()

    private let supportedCodeTypes = [
        AVMetadataObject.ObjectType.qr
    ]

    init(title: String, addHints: String? = nil, showTroubleshooting: Bool = false) {
        self.addHints = addHints
        self.showTroubleshooting = showTroubleshooting
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = []
        self.setupInfoLabel()
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            self.setupQRCodeScanner()
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: {  [weak self] (granted: Bool) in
                guard let self else { return }
                DispatchQueue.main.async {
                    if granted {
                        self.setupQRCodeScanner()
                    } else {
                        self.showCameraWarning()
                        self.showPermissionAlert()
                    }
                }
            })
        }

        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = moreButton
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
            self.showCameraWarning()
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
            self.showCameraWarning()
            return
        }
        view.layer.addSublayer(videoPreviewLayer)
        videoPreviewLayer.frame = view.layer.bounds
        view.bringSubviewToFront(infoLabel)
    }
    
    private func setupInfoLabel() {
        view.addSubview(infoLabel)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabelBottomConstraint = infoLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        infoLabelCenterConstraint = infoLabel.constraintCenterYTo(view)
        infoLabelBottomConstraint?.isActive = true
        infoLabel.constraintAlignLeadingTo(view, paddingLeading: 5).isActive = true
        infoLabel.constraintAlignTrailingTo(view, paddingTrailing: 5).isActive = true
    }
    
    private func showCameraWarning() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let text = String.localized("chat_camera_unavailable")
            logger.error(text)
            self.infoLabel.textColor = DcColors.defaultTextColor
            self.infoLabel.text = text
            self.infoLabelBottomConstraint?.isActive = false
            self.infoLabelCenterConstraint?.isActive = true
        }
    }
    
    private func showPermissionAlert() {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: String.localized("perm_required_title"),
                                          message: String.localized("perm_ios_explain_access_to_camera_denied"),
                                          preferredStyle: .alert)
            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                alert.addAction(UIAlertAction(title: String.localized("open_settings"), style: .default, handler: { _ in
                        UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)}))
                alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .destructive, handler: nil))
            }
            self?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func updateVideoOrientation() {

        guard let connection = videoPreviewLayer.connection,
                connection.isVideoOrientationSupported,
              let statusBarOrientation = UIApplication.shared.orientation else {
            return
        }
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
            DispatchQueue.global(qos: .userInteractive).async {
                self.captureSession.startRunning()
            }
        #endif
    }

     
    func stopSession() {
        captureSession.stopRunning()
    }

    private func moreButtonMenu() -> UIMenu {
        var actions = [UIMenuElement]()
        actions.append(UIAction(title: String.localized("paste_from_clipboard"), image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in
            self?.delegate?.handleQrCode(UIPasteboard.general.string ?? "")
        })
        if showTroubleshooting {
            actions.append(UIAction(title: String.localized("troubleshooting"), image: UIImage(systemName: "questionmark.circle")) { [weak self] _ in
                self?.openHelp(fragment: "#multiclient")
            })
        }
        return UIMenu(children: actions)
    }

    @objc func onCancelPressed() {
        navigationController?.popViewController(animated: true)
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

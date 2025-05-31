import Foundation
import SCSiriWaveformView
import AVKit
import DcCore

protocol AudioRecorderControllerDelegate: AnyObject {
    func didFinishAudioAtPath(path: String)
    func didClose()
}

class AudioRecorderController: UIViewController, AVAudioRecorderDelegate {

    weak var delegate: AudioRecorderControllerDelegate?

    // Recording...
    var meterUpdateDisplayLink: CADisplayLink?
    var isRecordingPaused: Bool = false

    private let bitrateBalanced = 32000
    private let bitrateWorse    = 24000
    private let bitrate: Int

    // Private variables
    var oldSessionCategory: AVAudioSession.Category?
    var wasIdleTimerDisabled: Bool = false

    var recordingFilePath: String = ""
    var audioRecorder: AVAudioRecorder?

    var isFirstUsage: Bool = true

    lazy var waveFormView: SCSiriWaveformView = {
        let view = SCSiriWaveformView()
        view.isHidden = true
        view.waveColor = .clear
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.primaryWaveLineWidth = 3.0
        view.secondaryWaveLineWidth = 1.0
        return view
    }()

    lazy var noRecordingPermissionView: UILabel = {
        let view = UILabel()
        view.isHidden = true
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = DcColors.defaultTextColor
        view.lineBreakMode = .byWordWrapping
        view.numberOfLines = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        view.text = String.localized("perm_required_title") + " - " + String.localized("perm_explain_access_to_mic_denied")
        view.textAlignment = .center
        return view
    }()

    lazy var cancelButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelAction))
    }()

    lazy var doneButton: UIBarButtonItem = {
        return UIBarButtonItem(title: String.localized("menu_send"), style: .done, target: self, action: #selector(doneAction))
    }()

    lazy var pauseButton: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "pause"), style: .plain, target: self, action: #selector(pauseRecording))
    }()

    lazy var startRecordingButton: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "mic"), style: .plain, target: self, action: #selector(startRecording))
    }()

    lazy var continueRecordingButton: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "mic"), style: .plain, target: self, action: #selector(continueRecording))
    }()

    init(dcContext: DcContext) {
        bitrate = dcContext.getConfigInt("media_quality") == 1 ? bitrateWorse : bitrateBalanced
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.accessibilityViewIsModal = true
        self.view.backgroundColor = UIColor.themeColor(light: .white, dark: .black)
        self.navigationController?.isToolbarHidden = false
        self.navigationController?.toolbar.isTranslucent = true
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.isModalInPresentation = true

        self.navigationItem.leftBarButtonItem = cancelButton
        self.navigationItem.rightBarButtonItem = doneButton

        waveFormView.frame = self.view.bounds
        self.view.addSubview(waveFormView)
        self.view.addSubview(noRecordingPermissionView)

        waveFormView.fill(view: view)
        noRecordingPermissionView.fill(view: view, paddingLeading: 10, paddingTrailing: 10)

        let recordSettings = [AVFormatIDKey: kAudioFormatMPEG4AAC_HE,
                              AVSampleRateKey: 44100.0,
                              AVEncoderBitRateKey: bitrate,
                              AVNumberOfChannelsKey: 1] as [String: Any]
        let globallyUniqueString = ProcessInfo.processInfo.globallyUniqueString
        recordingFilePath = NSTemporaryDirectory().appending(globallyUniqueString).appending(".m4a")
        do {
            audioRecorder = try AVAudioRecorder(url: URL(fileURLWithPath: recordingFilePath), settings: recordSettings)
        } catch {
            logger.error("Cannot init AVAudioRecorder: \(error)")
        }
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
    }


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        startUpdatingMeter()

        wasIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didBecomeActiveNotification),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
        validateMicrophoneAccess()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .layoutChanged, argument: self.doneButton)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        audioRecorder?.delegate = nil
        audioRecorder?.stop()
        audioRecorder = nil
        stopUpdatingMeter()
        UIApplication.shared.isIdleTimerDisabled = wasIdleTimerDisabled
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        delegate?.didClose()
    }

    func startUpdatingMeter() {
        meterUpdateDisplayLink?.invalidate()
        meterUpdateDisplayLink = CADisplayLink.init(target: self, selector: #selector(updateMeters))
        meterUpdateDisplayLink?.add(to: RunLoop.current, forMode: RunLoop.Mode.common)
    }

    func stopUpdatingMeter() {
        meterUpdateDisplayLink?.invalidate()
        meterUpdateDisplayLink = nil
    }

    @objc func updateMeters() {
        guard let audioRecorder else { return }
        if isRecordingPaused {
            waveFormView.idleAmplitude = 0
            waveFormView.waveColor = UIColor.systemGray2
            waveFormView.update(withLevel: 0)
        } else {
            audioRecorder.updateMeters()
            let normalizedValue: Float = pow(10, audioRecorder.averagePower(forChannel: 0) / 20)
            waveFormView.idleAmplitude = 0.01
            waveFormView.waveColor = UIColor.systemRed
            waveFormView.update(withLevel: CGFloat(normalizedValue))
            self.navigationItem.title = String.timeStringForInterval(audioRecorder.currentTime)
        }
    }

    @objc func startRecording() {
        do {
            self.setToolbarItems([pauseButton], animated: true)
            doneButton.isEnabled = true
            if FileManager.default.fileExists(atPath: recordingFilePath) {
                try FileManager.default.removeItem(atPath: recordingFilePath)
            }
            let session = AVAudioSession.sharedInstance()
            oldSessionCategory = session.category
            try session.setCategory(AVAudioSession.Category.record)
            UIApplication.shared.isIdleTimerDisabled = true
            guard let audioRecorder, audioRecorder.prepareToRecord() else { logger.error("prepareToRecord() failed"); return }
            isRecordingPaused = false
            guard audioRecorder.record() else { logger.error("record() failed"); return }
        } catch {
            logger.error("Cannot start recording: \(error)")
        }
    }

    @objc func continueRecording() {
        self.setToolbarItems([pauseButton], animated: true)
        isRecordingPaused = false
        guard let audioRecorder, audioRecorder.record() else { logger.error("continue recording failed"); return  }
    }

    @objc func pauseRecording() {
        isRecordingPaused = true
        audioRecorder?.pause()
        self.setToolbarItems([continueRecordingButton], animated: true)
    }

    @objc func cancelAction() {
        audioRecorder?.stop()
        do {
            try FileManager.default.removeItem(atPath: recordingFilePath)
        } catch {
            logger.error("Cannot cancel action: \(error)")
        }
        dismiss(animated: true, completion: nil)
    }

    @objc func doneAction() {
        isRecordingPaused = false
        audioRecorder?.stop()
        if let delegate = self.delegate {
            delegate.didFinishAudioAtPath(path: recordingFilePath)
        }
        dismiss(animated: true, completion: nil)
    }

    @objc func didBecomeActiveNotification() {
        validateMicrophoneAccess()
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        do {
            if flag {
                self.setToolbarItems([startRecordingButton], animated: true)
                if let oldSessionCategory = oldSessionCategory {
                    try AVAudioSession.sharedInstance().setCategory(oldSessionCategory)
                    UIApplication.shared.isIdleTimerDisabled = wasIdleTimerDisabled
                }
            } else {
                try FileManager.default.removeItem(at: URL(fileURLWithPath: recordingFilePath))
            }
        } catch {
            logger.error("Error in audioRecorderDidFinishRecording: \(error)")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        logger.error("audio recording failed: \(error?.localizedDescription ?? "unknown")")
    }

    func validateMicrophoneAccess() {
        let audioSession = AVAudioSession.sharedInstance()
        audioSession.requestRecordPermission({ granted in
            DispatchQueue.main.async { [weak self] in
                if let self {
                    self.noRecordingPermissionView.isHidden = granted
                    self.waveFormView.isHidden = !granted
                    self.doneButton.isEnabled = granted

                    if self.isFirstUsage {
                        if !granted {
                            self.setToolbarItems([self.startRecordingButton], animated: true)
                            self.startRecordingButton.isEnabled = false
                        } else {
                            self.pauseButton.isEnabled = granted
                            self.startRecording()
                        }

                        self.isFirstUsage = false
                    } else {
                        self.startRecordingButton.isEnabled = granted
                    }
                }
            }
        })
    }

}

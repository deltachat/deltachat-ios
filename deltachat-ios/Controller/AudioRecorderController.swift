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

    // maximumRecordDuration > 0 -> restrict max time period for one take
    var maximumRecordDuration = 0.0

    // Private variables
    var oldSessionCategory: AVAudioSession.Category?
    var wasIdleTimerDisabled: Bool = false

    var recordingFilePath: String = ""
    var audioRecorder: AVAudioRecorder?

    var normalTintColor: UIColor = UIColor.systemBlue
    var highlightedTintColor = UIColor.systemRed

    var isFirstUsage: Bool = true

    lazy var waveFormView: SCSiriWaveformView = {
        let view = SCSiriWaveformView()
        view.alpha = 0.0
        view.waveColor = .clear
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.primaryWaveLineWidth = 3.0
        view.secondaryWaveLineWidth = 1.0
        return view
    }()

    lazy var noRecordingPermissionView: UILabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = DcColors.defaultTextColor
        view.lineBreakMode = .byWordWrapping
        view.numberOfLines = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        view.text = String.localized("perm_required_title") + "\n\n" + String.localized("perm_explain_access_to_mic_denied")
        view.textAlignment = .center
        return view
    }()

    lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel,
                                          target: self,
                                          action: #selector(cancelAction))
        return button
    }()

    lazy var doneButton: UIBarButtonItem = {
        let button = UIBarButtonItem.init(title: String.localized("menu_send"),
                                          style: UIBarButtonItem.Style.done,
                                          target: self,
                                          action: #selector(doneAction))
        return button
    }()

    lazy var cancelRecordingButton: UIBarButtonItem = {
        let button = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.trash,
                                                 target: self,
                                                 action: #selector(cancelRecordingAction))
        button.tintColor = UIColor.themeColor(light: .darkGray, dark: .lightGray)
        return button
    }()

    lazy var pauseButton: UIBarButtonItem = {
        let button = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.pause,
                                          target: self,
                                          action: #selector(pauseRecordingButtonAction))
        button.tintColor = UIColor.themeColor(light: .darkGray, dark: .lightGray)
        return button
    }()

    lazy var startRecordingButton: UIBarButtonItem = {
        let button =  UIBarButtonItem.init(image: UIImage(systemName: "mic"),
                                           style: UIBarButtonItem.Style.plain,
                                           target: self,
                                           action: #selector(recordingButtonAction))
        button.tintColor = UIColor.themeColor(light: .darkGray, dark: .lightGray)
        return button
    }()

    lazy var continueRecordingButton: UIBarButtonItem = {
        let button = UIBarButtonItem.init(image: UIImage(systemName: "mic"),
                                          style: UIBarButtonItem.Style.plain,
                                          target: self,
                                          action: #selector(continueRecordingButtonAction))
        button.tintColor = UIColor.themeColor(light: .darkGray, dark: .lightGray)
        return button
    }()

    lazy var flexItem = {
        return UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
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

        self.navigationItem.title = String.localized("voice_message")
        self.navigationItem.leftBarButtonItem = cancelButton
        self.navigationItem.rightBarButtonItem = doneButton

        waveFormView.frame = self.view.bounds
        self.view.addSubview(waveFormView)
        self.view.addSubview(noRecordingPermissionView)

        waveFormView.fill(view: view)
        noRecordingPermissionView.fill(view: view, paddingLeading: 10, paddingTrailing: 10)

        self.navigationController?.toolbar.tintColor = normalTintColor
        self.navigationController?.navigationBar.tintColor = normalTintColor
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.toolbar.isTranslucent = true

        let recordSettings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                              AVSampleRateKey: 44100.0,
                              AVEncoderBitRateKey: 32000,
                              AVNumberOfChannelsKey: 1] as [String: Any]
        let globallyUniqueString = ProcessInfo.processInfo.globallyUniqueString
        recordingFilePath = NSTemporaryDirectory().appending(globallyUniqueString).appending(".m4a")
        audioRecorder = try? AVAudioRecorder.init(url: URL(fileURLWithPath: recordingFilePath), settings: recordSettings)
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
        if let audioRecorder = audioRecorder {
            if audioRecorder.isRecording || isRecordingPaused {
                audioRecorder.updateMeters()
                let normalizedValue: Float = pow(10, audioRecorder.averagePower(forChannel: 0) / 20)
                waveFormView.waveColor = highlightedTintColor
                waveFormView.update(withLevel: CGFloat(normalizedValue))
                self.navigationItem.title = String.timeStringForInterval(audioRecorder.currentTime)
            } else {
                waveFormView.waveColor = normalTintColor
                waveFormView.update(withLevel: 0)
            }
        }
    }

    @objc func recordingButtonAction() {
        self.setToolbarItems([flexItem, cancelRecordingButton, flexItem, pauseButton, flexItem], animated: true)
        cancelRecordingButton.isEnabled = true
        doneButton.isEnabled = true
        if FileManager.default.fileExists(atPath: recordingFilePath) {
            _ = try? FileManager.default.removeItem(atPath: recordingFilePath)
        }
        let session = AVAudioSession.sharedInstance()
        oldSessionCategory = session.category
        _ = try? session.setCategory(AVAudioSession.Category.record)
        UIApplication.shared.isIdleTimerDisabled = true
        audioRecorder?.prepareToRecord()
        isRecordingPaused = false

        if maximumRecordDuration <= 0 {
            audioRecorder?.record()
        } else {
            audioRecorder?.record(forDuration: maximumRecordDuration)
        }
    }

    @objc func continueRecordingButtonAction() {
        self.setToolbarItems([flexItem, cancelRecordingButton, flexItem, pauseButton, flexItem], animated: true)
        isRecordingPaused = false
        audioRecorder?.record()
    }

    @objc func pauseRecordingButtonAction() {
        isRecordingPaused = true
        audioRecorder?.pause()
        self.setToolbarItems([flexItem, cancelRecordingButton, flexItem, continueRecordingButton, flexItem], animated: true)
    }

    @objc func cancelRecordingAction() {
        isRecordingPaused = false
        cancelRecordingButton.isEnabled = false
        doneButton.isEnabled = false
        audioRecorder?.stop()
        _ = try? FileManager.default.removeItem(atPath: recordingFilePath)
        self.navigationItem.title = String.localized("voice_message")
    }

    @objc func cancelAction() {
        cancelRecordingAction()
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
        if flag {
            self.setToolbarItems([flexItem, cancelRecordingButton, flexItem, startRecordingButton, flexItem], animated: true)
            if let oldSessionCategory = oldSessionCategory {
               _ = try? AVAudioSession.sharedInstance().setCategory(oldSessionCategory)
               UIApplication.shared.isIdleTimerDisabled = wasIdleTimerDisabled
            }
        } else {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: recordingFilePath))
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
                    self.noRecordingPermissionView.alpha = granted ? 0.0 : 1.0
                    self.waveFormView.alpha = granted ? 1.0 : 0.0
                    self.doneButton.isEnabled = granted

                    if self.isFirstUsage {
                        if !granted {
                            self.setToolbarItems([self.flexItem, self.startRecordingButton, self.flexItem], animated: true)
                            self.startRecordingButton.isEnabled = false
                        } else {
                            self.pauseButton.isEnabled = granted
                            self.recordingButtonAction()
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

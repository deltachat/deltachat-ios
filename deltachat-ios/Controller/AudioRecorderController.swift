import Foundation
import SCSiriWaveformView
import AVKit

protocol AudioRecorderControllerDelegate: class {
    func didFinishAudioAtPath(path: String)
}

class AudioRecorderController: UIViewController, AVAudioRecorderDelegate {

    weak var delegate: AudioRecorderControllerDelegate?

    //Recording...
    var meterUpdateDisplayLink: CADisplayLink?
    var isRecordingPaused: Bool = false

    // maximumRecordDuration > 0 -> restrict max time period for one take
    var maximumRecordDuration = 0.0

    //Private variables
    var oldSessionCategory: AVAudioSession.Category?
    var wasIdleTimerDisabled: Bool = false

    var recordingFilePath: String = ""
    var audioRecorder: AVAudioRecorder?

    var normalTintColor: UIColor = UIColor.sendButtonBlue
    var highlightedTintColor = UIColor.red

    var isFirstUsage: Bool = true

    lazy var musicFlowView: SCSiriWaveformView = {
        let view = SCSiriWaveformView()
        view.alpha = 1.0
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.primaryWaveLineWidth = 3.0
        view.secondaryWaveLineWidth = 1.0
        return view
    }()

    //Access
    var viewMicrophoneDenied: UIView = {
        return UIView()
    }()

    var navigationTitle: NSString?

    lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel,
                                          target: self,
                                          action: #selector(cancelAction))
        return button
    }()

    lazy var doneButton: UIBarButtonItem = {
        let button = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.done,
                                          target: self,
                                          action: #selector(doneAction))
        return button
    }()

    lazy var cancelRecordingButton: UIBarButtonItem = {
        let button = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel,
                                                 target: self,
                                                 action: #selector(cancelRecordingAction))
        button.tintColor = highlightedTintColor
        return button
    }()

    lazy var pauseButton: UIBarButtonItem = {
        let button = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.pause,
                                          target: self,
                                          action: #selector(pauseRecordingButtonAction))
        button.tintColor = highlightedTintColor
        return button
    }()

    lazy var startRecordingButton: UIBarButtonItem = {
        let button =  UIBarButtonItem.init(image: UIImage(named: "audio_record"),
                                           style: UIBarButtonItem.Style.plain,
                                           target: self,
                                           action: #selector(recordingButtonAction))
        button.tintColor = normalTintColor
        return button
    }()

    lazy var continueRecordingButton: UIBarButtonItem = {
        let button = UIBarButtonItem.init(image: UIImage(named: "audio_record"),
                                          style: UIBarButtonItem.Style.plain,
                                          target: self,
                                          action: #selector(continueRecordingButtonAction))
        button.tintColor = highlightedTintColor
        return button
    }()

    lazy var flexItem = {
        return UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.themeColor(light: .white, dark: .black)
        self.navigationController?.isToolbarHidden = false
        self.navigationController?.toolbar.isTranslucent = true
        self.navigationController?.navigationBar.isTranslucent = true

        self.navigationItem.title = String.localized("voice_message")
        self.navigationItem.leftBarButtonItem = cancelButton
        self.navigationItem.rightBarButtonItem = doneButton
        musicFlowView.frame = self.view.bounds
        self.view.addSubview(musicFlowView)

        self.view.addConstraints([
            musicFlowView.constraintCenterXTo(view),
            musicFlowView.constraintCenterYTo(view),
            musicFlowView.constraintAlignTopTo(view),
            musicFlowView.constraintAlignBottomTo(view),
            musicFlowView.constraintAlignLeadingTo(view),
            musicFlowView.constraintAlignTrailingTo(view)
        ])

        self.navigationController?.toolbar.tintColor = normalTintColor
        self.navigationController?.navigationBar.tintColor = normalTintColor
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.toolbar.isTranslucent = true

        //Define the recorder setting
        let recordSettings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                              AVSampleRateKey: 44100.0,
                              AVNumberOfChannelsKey: 1] as [String: Any]
        let globallyUniqueString = ProcessInfo.processInfo.globallyUniqueString
        recordingFilePath = NSTemporaryDirectory().appending(globallyUniqueString).appending(".m4a")
        _ = try? audioRecorder = AVAudioRecorder.init(url: URL(fileURLWithPath: recordingFilePath), settings: recordSettings)
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        audioRecorder?.delegate = nil
        audioRecorder?.stop()
        audioRecorder = nil
        stopUpdatingMeter()
        UIApplication.shared.isIdleTimerDisabled = wasIdleTimerDisabled
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
                musicFlowView.waveColor = highlightedTintColor
                musicFlowView.update(withLevel: CGFloat(normalizedValue))
                self.navigationItem.title = String.timeStringForInterval(audioRecorder.currentTime)
            } else {
                musicFlowView.waveColor = normalTintColor
                musicFlowView.update(withLevel: 0)
            }
        }
    }

    @objc func recordingButtonAction() {
        logger.debug("start recording")
        self.setToolbarItems([flexItem, pauseButton, flexItem], animated: true)
        self.navigationItem.setLeftBarButton(cancelRecordingButton, animated: true)
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
        logger.debug("continue recording")
        self.setToolbarItems([flexItem, pauseButton, flexItem], animated: true)
        isRecordingPaused = false
        audioRecorder?.record()
    }

    @objc func pauseRecordingButtonAction() {
        logger.debug("pause")
        isRecordingPaused = true
        audioRecorder?.pause()
        self.setToolbarItems([flexItem, continueRecordingButton, flexItem], animated: true)
    }

    @objc func cancelRecordingAction() {
        logger.debug("cancel recording")
        isRecordingPaused = false
        audioRecorder?.stop()
        _ = try? FileManager.default.removeItem(atPath: recordingFilePath)
        self.navigationItem.title = String.localized("voice_message")
    }

    @objc func cancelAction() {
        logger.debug("cancel Action")
        dismiss(animated: true, completion: nil)
    }

    @objc func doneAction() {
        logger.debug("done with Action")
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
            self.setToolbarItems([flexItem, startRecordingButton, flexItem], animated: true)
            if let oldSessionCategory = oldSessionCategory {
               _ = try? AVAudioSession.sharedInstance().setCategory(oldSessionCategory)
               UIApplication.shared.isIdleTimerDisabled = wasIdleTimerDisabled
            }
        } else {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: recordingFilePath))
        }
         self.navigationItem.setLeftBarButton(cancelButton, animated: true)
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        logger.error("audio recording failed: \(error?.localizedDescription ?? "unknown")")
    }

    func validateMicrophoneAccess() {
        let audioSession = AVAudioSession.sharedInstance()
        audioSession.requestRecordPermission({(granted: Bool) -> Void in
            if granted {

                DispatchQueue.main.async { [weak self] in
                    //self?.viewMicrophoneDenied.alpha =
                    //self?.musicFlowView.alpha = granted ? 1.0 : 0.0
                    if let self = self {
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
            }
        })
    }
}

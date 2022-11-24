import UIKit
import DcCore

public class LogViewController: UIViewController {

    private let dcContext: DcContext

    private lazy var logText: UITextView = {
        let label = UITextView()
        label.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 0, right: 0)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
        self.navigationItem.title = String.localized("pref_log_header")
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        setupSubviews()
    }

    private func setupSubviews() {
        self.view.addSubview(logText)
        self.view.backgroundColor = DcColors.defaultBackgroundColor
        self.view.addConstraints([
            logText.constraintAlignTopToAnchor(view.safeAreaLayoutGuide.topAnchor),
            logText.constraintAlignLeadingToAnchor(view.safeAreaLayoutGuide.leadingAnchor, paddingLeading: 12),
            logText.constraintAlignTrailingToAnchor(view.safeAreaLayoutGuide.trailingAnchor, paddingTrailing: 12),
            logText.constraintAlignBottomToAnchor(view.safeAreaLayoutGuide.bottomAnchor, paddingBottom: 12)
        ])
        logText.text = getDebugVariables(dcContext: dcContext)
        logText.setContentOffset(.zero, animated: false)
    }

    @objc
    private func doneButtonPressed() {
        dismiss(animated: true)
    }

    public func getDebugVariables(dcContext: DcContext) -> String {
        var info = ""

        let systemVersion = UIDevice.current.systemVersion
        info += "iosVersion=\(systemVersion)\n"

        let notifyEnabled = !UserDefaults.standard.bool(forKey: "notifications_disabled")
        info += "notify-enabled=\(notifyEnabled)\n"

        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            info += "notify-token=\(appDelegate.notifyToken ?? "<unset>")\n"
        }

        for name in ["notify-remote-launch", "notify-remote-receive", "notify-local-wakeup"] {
            let cnt = UserDefaults.standard.integer(forKey: name + "-count")

            let startDbl = UserDefaults.standard.double(forKey: name + "-start")
            let startStr = startDbl==0.0 ? "" : " since " + DateUtils.getExtendedRelativeTimeSpanString(timeStamp: startDbl)

            let timestampDbl = UserDefaults.standard.double(forKey: name + "-last")
            let timestampStr = timestampDbl==0.0 ? "" : ", last " + DateUtils.getExtendedRelativeTimeSpanString(timeStamp: timestampDbl)

            info += "\(name)=\(cnt)x\(startStr)\(timestampStr)\n"
        }

        info += "notify-timestamps="
        if let timestamps = UserDefaults.standard.array(forKey: Constants.Keys.notificationTimestamps) as? [Double] {
            for currTimestamp in timestamps {
                info += DateUtils.getExtendedAbsTimeSpanString(timeStamp: currTimestamp) + " "
            }
        }
        info += "\n"

        info += "notify-fetch-info2="
        if let infos = UserDefaults.standard.array(forKey: "notify-fetch-info2")  as? [String] {
            for currInfo in infos {
                info += currInfo
                    .replacingOccurrences(of: "📡", with: "\n📡")
                    .replacingOccurrences(of: "🏠", with: "\n🏠") + " "
            }
        }
        info += "\n"

        var val = "?"
        switch UIApplication.shared.backgroundRefreshStatus {
        case .restricted: val = "restricted"
        case .available: val = "available"
        case .denied: val = "denied"
        }
        info += "backgroundRefreshStatus=\(val)\n"

        #if DEBUG
        info += "DEBUG=1\n"
        #else
        info += "DEBUG=0\n"
        #endif

        info += "\n" + dcContext.getInfo()

        return info
    }

}

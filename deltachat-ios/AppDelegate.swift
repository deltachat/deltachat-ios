import AudioToolbox
import DBDebugToolkit
import Reachability
import SwiftyBeaver
import UIKit
import UserNotifications

var mailboxPointer: OpaquePointer!
let logger = SwiftyBeaver.self

enum ApplicationState {
    case stopped
    case running
    case background
    case backgroundFetch
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let dcContext = DcContext()
    var appCoordinator: AppCoordinator!
    // static let appCoordinatorDeprecated = AppCoordinatorDeprecated()
    static var progress: Float = 0 // TODO: delete
    static var lastErrorString: String?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    var reachability = Reachability()!
    var window: UIWindow?

    var state = ApplicationState.stopped

    private func getCoreInfo() -> [[String]] {
        if let cString = dc_get_info(mailboxPointer) {
            let info = String(cString: cString)
            dc_str_unref(cString)
            logger.info(info)
            return info.components(separatedBy: "\n").map { val in
                val.components(separatedBy: "=")
            }
        }

        return []
    }

    func application(_: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // gets here when app returns from oAuth2-Setup process - the url contains the provided token
        if let params = url.queryParameters, let token = params["code"] {
            NotificationCenter.default.post(name: NSNotification.Name("oauthLoginApproved"), object: nil, userInfo: ["token": token])
        }

        // Hack to format url properly
        let urlString = url.absoluteString
                       .replacingOccurrences(of: "openpgp4fpr", with: "OPENPGP4FPR", options: .literal, range: nil)
                       .replacingOccurrences(of: "%23", with: "#", options: .literal, range: nil)

        self.appCoordinator.handleQRCode(urlString)
        return true
    }

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        DBDebugToolkit.setup()
        DBDebugToolkit.setupCrashReporting()

        let console = ConsoleDestination()
        logger.addDestination(console)

        logger.info("launching")

        // Override point for customization after application launch.

        window = UIWindow(frame: UIScreen.main.bounds)
        guard let window = window else {
            fatalError("window was nil in app delegate")
        }
        // setup deltachat core context
        //       - second param remains nil (user data for more than one mailbox)
        open()
        appCoordinator = AppCoordinator(window: window, dcContext: dcContext)
        appCoordinator.start()
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        start()
        setStockTranslations()
        return true
    }

    func application(_: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logger.info("---- background-fetch ----")

        start {
            // TODO: actually set the right value depending on if we found sth
            completionHandler(.newData)
        }
    }

    func applicationWillEnterForeground(_: UIApplication) {
        logger.info("---- foreground ----")
        start()
    }

    func applicationDidEnterBackground(_: UIApplication) {
        logger.info("---- background ----")

        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)

        maybeStop()
    }

    private func maybeStop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            let app = UIApplication.shared
            logger.info("state: \(app.applicationState) time remaining \(app.backgroundTimeRemaining)")

            if app.applicationState != .background {
                // only need to do sth in the background
                return
            } else if app.backgroundTimeRemaining < 10 {
                self.stop()
            } else {
                self.maybeStop()
            }
        }
    }

    func applicationWillTerminate(_: UIApplication) {
        logger.info("---- terminate ----")
        close()

        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)
    }

    func dbfile() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        let documentsPath = paths[0]

        return documentsPath + "/messenger.db"
    }

    func open() {
        logger.info("open: \(dbfile())")

        if mailboxPointer == nil {
            mailboxPointer = dcContext.contextPointer
            guard mailboxPointer != nil else {
                fatalError("Error: dc_context_new returned nil")
            }
        }
        _ = dc_open(mailboxPointer, dbfile(), nil)
    }

    func setStockTranslations() {
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_NOMESSAGES), String.localized("chat_no_messages"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_SELF), String.localized("self"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_DRAFT), String.localized("draft"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_VOICEMESSAGE), String.localized("voice_message"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_DEADDROP), String.localized("chat_contact_request"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_IMAGE), String.localized("image"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_VIDEO), String.localized("video"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_AUDIO), String.localized("audio"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_FILE), String.localized("file"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_STATUSLINE), String.localized("pref_default_status_text"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_NEWGROUPDRAFT), String.localized("group_hello_draft"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_MSGGRPNAME), String.localized("systemmsg_group_name_changed"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_MSGGRPIMGCHANGED), String.localized("systemmsg_group_image_changed"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_MSGADDMEMBER), String.localized("systemmsg_member_added"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_MSGDELMEMBER), String.localized("systemmsg_member_removed"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_MSGGROUPLEFT), String.localized("systemmsg_group_left"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_GIF), String.localized("gif"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_CANTDECRYPT_MSG_BODY), String.localized("systemmsg_cannot_decrypt"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_READRCPT), String.localized("systemmsg_read_receipt_subject"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_READRCPT_MAILBODY), String.localized("systemmsg_read_receipt_body"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_MSGGRPIMGDELETED), String.localized("systemmsg_group_image_deleted"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_CONTACT_VERIFIED), String.localized("contact_verified"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_CONTACT_NOT_VERIFIED), String.localized("contact_not_verified"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_CONTACT_SETUP_CHANGED), String.localized("contact_setup_changed"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_ARCHIVEDCHATS), String.localized("chat_archived_chats_title"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_AC_SETUP_MSG_SUBJECT), String.localized("autocrypt_asm_subject"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_AC_SETUP_MSG_BODY), String.localized("autocrypt_asm_general_body"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_CANNOT_LOGIN), String.localized("login_error_cannot_login"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_SERVER_RESPONSE), String.localized("login_error_server_response"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_MSGACTIONBYUSER), String.localized("systemmsg_action_by_user"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_MSGACTIONBYME), String.localized("systemmsg_action_by_me"))
        dc_set_stock_translation(mailboxPointer, UInt32(DC_STR_DEVICE_MESSAGES), String.localized("device_talk"))
    }

    func stop() {
        state = .background

        dc_interrupt_imap_idle(mailboxPointer)
        dc_interrupt_smtp_idle(mailboxPointer)
        dc_interrupt_mvbox_idle(mailboxPointer)
        dc_interrupt_sentbox_idle(mailboxPointer)
    }

    func close() {
        state = .stopped
        dc_close(mailboxPointer)
        mailboxPointer = nil
    }

    func start(_ completion: (() -> Void)? = nil) {
        logger.info("---- start ----")

        if state == .running {
            return
        }

        state = .running

        DispatchQueue.global(qos: .background).async {
            self.registerBackgroundTask()
            while self.state == .running {
                dc_perform_imap_jobs(mailboxPointer)
                dc_perform_imap_fetch(mailboxPointer)
                dc_perform_imap_idle(mailboxPointer)
            }
            if self.backgroundTask != .invalid {
                completion?()
                self.endBackgroundTask()
            }
        }

        DispatchQueue.global(qos: .utility).async {
            self.registerBackgroundTask()
            while self.state == .running {
                dc_perform_smtp_jobs(mailboxPointer)
                dc_perform_smtp_idle(mailboxPointer)
            }
            if self.backgroundTask != .invalid {
                self.endBackgroundTask()
            }
        }

        DispatchQueue.global(qos: .background).async {
            while self.state == .running {
                dc_perform_sentbox_jobs(mailboxPointer)
                dc_perform_sentbox_fetch(mailboxPointer)
                dc_perform_sentbox_idle(mailboxPointer)
            }
        }

        DispatchQueue.global(qos: .background).async {
            while self.state == .running {
                dc_perform_mvbox_jobs(mailboxPointer)
                dc_perform_mvbox_fetch(mailboxPointer)
                dc_perform_mvbox_idle(mailboxPointer)
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)),
                                               name: .reachabilityChanged, object: reachability)
        do {
            try reachability.startNotifier()
        } catch {
            logger.info("could not start reachability notifier")
        }

        let info: [DBCustomVariable] = getCoreInfo().map { kv in
            let value = kv.count > 1 ? kv[1] : ""
            return DBCustomVariable(name: kv[0], value: value)
        }

        DBDebugToolkit.add(info)
    }

    @objc private func reachabilityChanged(note: Notification) {
        guard let reachability = note.object as? Reachability else {
            logger.info("reachability object missing")
            return
        }

        switch reachability.connection {
        case .wifi, .cellular:
            logger.info("network: reachable", reachability.connection.description)

            // call dc_maybe_network() from a worker thread.
            // normally, dc_maybe_network() can be called uncoditionally,
            // however, in fact, it may halt things for some seconds.
            // this pr is a workaround that make things usable for now.
            DispatchQueue.global(qos: .background).async {
                dc_maybe_network(mailboxPointer)
            }
        case .none:
            logger.info("network: not reachable")
        }
    }

    // MARK: - BackgroundTask

    private func registerBackgroundTask() {
        logger.info("background task registered")
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        assert(backgroundTask != .invalid)
    }

    private func endBackgroundTask() {
        logger.info("background task ended")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    // MARK: - PushNotifications

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                logger.info("permission granted: \(granted)")
                guard granted else { return }
                self.getNotificationSettings()
            }
    }

    private func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            logger.info("Notification settings: \(settings)")
        }
    }

    private func userNotificationCenter(_: UNUserNotificationCenter, willPresent _: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        logger.info("forground notification")
        completionHandler([.alert, .sound])
    }

    private func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == Constants.notificationIdentifier {
            logger.info("handling notifications")
            let userInfo = response.notification.request.content.userInfo
            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                nc.post(
                    name: dcNotificationViewChat,
                    object: nil,
                    userInfo: userInfo
                )
            }
        }

        completionHandler()
    }
}

import AudioToolbox
import DBDebugToolkit
import Reachability
import SwiftyBeaver
import UIKit
import UserNotifications
import DcCore

let logger = SwiftyBeaver.self

enum ApplicationState {
    case stopped
    case running
    case background
    case backgroundFetch
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let dcContext = DcContext.shared
    var appCoordinator: AppCoordinator!
    var relayHelper: RelayHelper!
    var locationManager: LocationManager!
    // static let appCoordinatorDeprecated = AppCoordinatorDeprecated()
    static var progress: Float = 0 // TODO: delete
    static var lastErrorString: String?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    var reachability = Reachability()!
    var window: UIWindow?

    var state = ApplicationState.stopped

    func application(_: UIApplication, open url: URL, options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
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
        if #available(iOS 13.0, *) {
            window.backgroundColor = UIColor.systemBackground
        } else {
            window.backgroundColor = UIColor.white
        }
        // setup deltachat core context
        //       - second param remains nil (user data for more than one mailbox)
        open()
        RelayHelper.setup(dcContext)
        appCoordinator = AppCoordinator(window: window, dcContext: dcContext)
        appCoordinator.start()
        locationManager = LocationManager(context: dcContext)
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

    func open() {
        guard let databaseLocation = DatabaseHelper().updateDatabaseLocation() else {
            fatalError("Database could not be opened")
        }
        logger.info("open: \(databaseLocation)")
        dcContext.openDatabase(dbFile: databaseLocation)
    }

    func setStockTranslations() {
        dcContext.setStockTranslation(id: DC_STR_NOMESSAGES, localizationKey: "chat_no_messages")
        dcContext.setStockTranslation(id: DC_STR_SELF, localizationKey: "self")
        dcContext.setStockTranslation(id: DC_STR_DRAFT, localizationKey: "draft")
        dcContext.setStockTranslation(id: DC_STR_VOICEMESSAGE, localizationKey: "voice_message")
        dcContext.setStockTranslation(id: DC_STR_DEADDROP, localizationKey: "chat_contact_request")
        dcContext.setStockTranslation(id: DC_STR_IMAGE, localizationKey: "image")
        dcContext.setStockTranslation(id: DC_STR_VIDEO, localizationKey: "video")
        dcContext.setStockTranslation(id: DC_STR_AUDIO, localizationKey: "audio")
        dcContext.setStockTranslation(id: DC_STR_FILE, localizationKey: "file")
        dcContext.setStockTranslation(id: DC_STR_STATUSLINE, localizationKey: "pref_default_status_text")
        dcContext.setStockTranslation(id: DC_STR_NEWGROUPDRAFT, localizationKey: "group_hello_draft")
        dcContext.setStockTranslation(id: DC_STR_MSGGRPNAME, localizationKey: "systemmsg_group_name_changed")
        dcContext.setStockTranslation(id: DC_STR_MSGGRPIMGCHANGED, localizationKey: "systemmsg_group_image_changed")
        dcContext.setStockTranslation(id: DC_STR_MSGADDMEMBER, localizationKey: "systemmsg_member_added")
        dcContext.setStockTranslation(id: DC_STR_MSGDELMEMBER, localizationKey: "systemmsg_member_removed")
        dcContext.setStockTranslation(id: DC_STR_MSGGROUPLEFT, localizationKey: "systemmsg_group_left")
        dcContext.setStockTranslation(id: DC_STR_GIF, localizationKey: "gif")
        dcContext.setStockTranslation(id: DC_STR_CANTDECRYPT_MSG_BODY, localizationKey: "systemmsg_cannot_decrypt")
        dcContext.setStockTranslation(id: DC_STR_READRCPT, localizationKey: "systemmsg_read_receipt_subject")
        dcContext.setStockTranslation(id: DC_STR_READRCPT_MAILBODY, localizationKey: "systemmsg_read_receipt_body")
        dcContext.setStockTranslation(id: DC_STR_MSGGRPIMGDELETED, localizationKey: "systemmsg_group_image_deleted")
        dcContext.setStockTranslation(id: DC_STR_CONTACT_VERIFIED, localizationKey: "contact_verified")
        dcContext.setStockTranslation(id: DC_STR_CONTACT_NOT_VERIFIED, localizationKey: "contact_not_verified")
        dcContext.setStockTranslation(id: DC_STR_CONTACT_SETUP_CHANGED, localizationKey: "contact_setup_changed")
        dcContext.setStockTranslation(id: DC_STR_ARCHIVEDCHATS, localizationKey: "chat_archived_chats_title")
        dcContext.setStockTranslation(id: DC_STR_AC_SETUP_MSG_SUBJECT, localizationKey: "autocrypt_asm_subject")
        dcContext.setStockTranslation(id: DC_STR_AC_SETUP_MSG_BODY, localizationKey: "autocrypt_asm_general_body")
        dcContext.setStockTranslation(id: DC_STR_CANNOT_LOGIN, localizationKey: "login_error_cannot_login")
        dcContext.setStockTranslation(id: DC_STR_SERVER_RESPONSE, localizationKey: "login_error_server_response")
        dcContext.setStockTranslation(id: DC_STR_MSGACTIONBYUSER, localizationKey: "systemmsg_action_by_user")
        dcContext.setStockTranslation(id: DC_STR_MSGACTIONBYME, localizationKey: "systemmsg_action_by_me")
        dcContext.setStockTranslation(id: DC_STR_DEVICE_MESSAGES, localizationKey: "device_talk")
    }

    func stop() {
        state = .background
        dcContext.interruptIdle()
    }

    func close() {
        state = .stopped
        dcContext.closeDatabase()
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
                self.dcContext.performImap()
            }
            if self.backgroundTask != .invalid {
                completion?()
                self.endBackgroundTask()
            }
        }

        DispatchQueue.global(qos: .utility).async {
            self.registerBackgroundTask()
            while self.state == .running {
                self.dcContext.performSmtp()
            }
            if self.backgroundTask != .invalid {
                self.endBackgroundTask()
            }
        }

        DispatchQueue.global(qos: .background).async {
            while self.state == .running {
                self.dcContext.performSentbox()
            }
        }

        DispatchQueue.global(qos: .background).async {
            while self.state == .running {
                self.dcContext.performMoveBox()
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)),
                                               name: .reachabilityChanged, object: reachability)
        do {
            try reachability.startNotifier()
        } catch {
            logger.info("could not start reachability notifier")
        }

        let info: [DBCustomVariable] = dcContext.getInfo().map { kv in
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
                self.dcContext.maybeNetwork()
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

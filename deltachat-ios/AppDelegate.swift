import AudioToolbox
import Reachability
import SwiftyBeaver
import UIKit
import UserNotifications
import DcCore
import DBDebugToolkit

let logger = SwiftyBeaver.self

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let dcContext = DcContext.shared
    var appCoordinator: AppCoordinator!
    var relayHelper: RelayHelper!
    var locationManager: LocationManager!
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    var reachability = Reachability()!
    var window: UIWindow?
    var appIsInForeground = false
    var notifyToken: String?

    // `didFinishLaunchingWithOptions` is the main entry point
    // that is called if the app is started for the first time
    // or after the app is killed.
    //
    // `didFinishLaunchingWithOptions` creates the context object and sets
    // up other global things.
    //
    // `didFinishLaunchingWithOptions` is _not_ called
    // when the app wakes up from "suspended" state
    // (app is in memory in the background but no code is executed, IO stopped)
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // explicitly ignore SIGPIPE to avoid crashes, see https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/NetworkingOverview/CommonPitfalls/CommonPitfalls.html
        // setupCrashReporting() may create an additional handler, but we do not want to rely on that
        signal(SIGPIPE, SIG_IGN)

        DBDebugToolkit.setup(with: []) // empty array will override default device shake trigger
        DBDebugToolkit.setupCrashReporting()
        
        let console = ConsoleDestination()
        logger.addDestination(console)
        dcContext.logger = DcLogger()
        logger.info("launching")

        window = UIWindow(frame: UIScreen.main.bounds)
        guard let window = window else {
            fatalError("window was nil in app delegate")
        }
        if #available(iOS 13.0, *) {
            window.backgroundColor = UIColor.systemBackground
        } else {
            window.backgroundColor = UIColor.white
        }

        openDatabase()
        installEventHandler()
        RelayHelper.setup(dcContext)
        appCoordinator = AppCoordinator(window: window, dcContext: dcContext)
        locationManager = LocationManager(context: dcContext)
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        dcContext.maybeStartIo()
        setStockTranslations()

        reachability.whenReachable = { reachability in
            logger.info("network: reachable", reachability.connection.description)
            self.dcContext.maybeNetwork()
        }

        reachability.whenUnreachable = { _ in
            logger.info("network: not reachable")
        }

        do {
            try reachability.startNotifier()
        } catch {
            logger.error("Unable to start notifier")
        }
        
        if let notificationOption = launchOptions?[.remoteNotification] {
            logger.info("Notifications: remoteNotification: \(String(describing: notificationOption))")
            increaseDebugCounter("notify-remote-launch")
        }

        if dcContext.isConfigured() && !UserDefaults.standard.bool(forKey: "notifications_disabled") {
            registerForNotifications()
        }

        return true
    }

    // `open` is called when an url should be opened by Delta Chat.
    // we currently use that for handling oauth2 and for handing openpgp4fpr
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

    // `performFetchWithCompletionHandler` is called on local wakeup.
    // this requires "UIBackgroundModes: fetch" to be set in Info.plist
    // ("App downloads content from the network" in Xcode)
    //
    // we have 30 seconds time for our job, leave some seconds for graceful termination.
    // also, the faster we return, the sooner we get called again.
    func application(_: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logger.info("---- background-fetch ----")
        increaseDebugCounter("notify-local-wakeup")
        let oldFresh = DcContext.shared.getFreshMessages().count

        dcContext.maybeStartIo()
        dcContext.maybeNetwork()

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if !self.appIsInForeground {
                self.dcContext.stopIo()
            }
            completionHandler(DcContext.shared.getFreshMessages().count > oldFresh ? .newData : .noData)
        }
    }

    func applicationWillEnterForeground(_: UIApplication) {
        logger.info("---- foreground ----")
        appIsInForeground = true
        dcContext.maybeStartIo()
        if reachability.connection != .none {
            self.dcContext.maybeNetwork()
        }

        if let userDefaults = UserDefaults.shared, userDefaults.bool(forKey: UserDefaults.hasExtensionAttemptedToSend) {
            userDefaults.removeObject(forKey: UserDefaults.hasExtensionAttemptedToSend)
            let nc = NotificationCenter.default

            DispatchQueue.main.async {
                nc.post(
                    name: dcNotificationChanged,
                    object: nil,
                    userInfo: [:]
                )
            }
        }
    }

    func applicationDidEnterBackground(_: UIApplication) {
        logger.info("---- background ----")
        appIsInForeground = false
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
                self.dcContext.stopIo()
            } else {
                self.maybeStop()
            }
        }
    }

    func applicationWillTerminate(_: UIApplication) {
        logger.info("---- terminate ----")
        closeDatabase()

        reachability.stopNotifier()
    }

    func openDatabase() {
        guard let databaseLocation = DatabaseHelper().updateDatabaseLocation() else {
            fatalError("Database could not be opened")
        }
        logger.info("open: \(databaseLocation)")
        dcContext.openDatabase(dbFile: databaseLocation)
    }

    func closeDatabase() {
        dcContext.closeDatabase()
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
        dcContext.setStockTranslation(id: DC_STR_ENCRYPTEDMSG, localizationKey: "encrypted_message")
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
        dcContext.setStockTranslation(id: DC_STR_SAVED_MESSAGES, localizationKey: "saved_messages")
        dcContext.setStockTranslation(id: DC_STR_DEVICE_MESSAGES_HINT, localizationKey: "device_talk_explain")
        dcContext.setStockTranslation(id: DC_STR_WELCOME_MESSAGE, localizationKey: "device_talk_welcome_message")
        dcContext.setStockTranslation(id: DC_STR_UNKNOWN_SENDER_FOR_CHAT, localizationKey: "systemmsg_unknown_sender_for_chat")
        dcContext.setStockTranslation(id: DC_STR_SUBJECT_FOR_NEW_CONTACT, localizationKey: "systemmsg_subject_for_new_contact")
        dcContext.setStockTranslation(id: DC_STR_FAILED_SENDING_TO, localizationKey: "systemmsg_failed_sending_to")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_DISABLED, localizationKey: "systemmsg_ephemeral_timer_disabled")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_SECONDS, localizationKey: "systemmsg_ephemeral_timer_enabled")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_MINUTE, localizationKey: "systemmsg_ephemeral_timer_minute")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_HOUR, localizationKey: "systemmsg_ephemeral_timer_hour")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_DAY, localizationKey: "systemmsg_ephemeral_timer_day")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_WEEK, localizationKey: "systemmsg_ephemeral_timer_week")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_FOUR_WEEKS, localizationKey: "systemmsg_ephemeral_timer_four_weeks")
        dcContext.setStockTranslation(id: DC_STR_VIDEOCHAT_INVITATION, localizationKey: "videochat_invitation")
        dcContext.setStockTranslation(id: DC_STR_VIDEOCHAT_INVITE_MSG_BODY, localizationKey: "videochat_invitation_body")
        dcContext.setStockTranslation(id: DC_STR_CONFIGURATION_FAILED, localizationKey: "configuration_failed_with_error")
        dcContext.setStockTranslation(id: DC_STR_PROTECTION_ENABLED, localizationKey: "systemmsg_chat_protection_enabled")
        dcContext.setStockTranslation(id: DC_STR_PROTECTION_DISABLED, localizationKey: "systemmsg_chat_protection_disabled")
        dcContext.setStockTranslation(id: DC_STR_REPLY_NOUN, localizationKey: "reply_noun")
    }

    func installEventHandler() {
        DispatchQueue.global(qos: .background).async {
            self.registerBackgroundTask()
            let eventEmitter = self.dcContext.getEventEmitter()
            while true {
                guard let event = eventEmitter.getNextEvent() else { break }
                handleEvent(event: event)
            }
            if self.backgroundTask != .invalid {
                self.endBackgroundTask()
            }
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

    // `registerForNotifications` asks the user if they want to get notifiations shown.
    // if so, it registers for receiving push notifications.
    func registerForNotifications() {
        UNUserNotificationCenter.current().delegate = self
        notifyToken = nil

        // register for showing notifications
        UNUserNotificationCenter.current()
          .requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            logger.info("Notifications: Permission granted: \(granted)")

            if granted {
                // we are allowed to show notifications:
                // register for receiving push notifications
                self?.maybeRegisterForRemoteNotifications()
            }
        }
    }

    // register on apple server for receiving push notifications
    // and pass the token to the app's notification server.
    //
    // on success, we get a token at didRegisterForRemoteNotificationsWithDeviceToken;
    // on failure, didFailToRegisterForRemoteNotificationsWithError is called
    private func maybeRegisterForRemoteNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            logger.info("Notifications: Settings: \(settings)")

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                  UIApplication.shared.registerForRemoteNotifications()
                }
            case .denied, .notDetermined:
                break
            }
        }
    }

    // `didRegisterForRemoteNotificationsWithDeviceToken` is called by iOS
    // when the call to `UIApplication.shared.registerForRemoteNotifications` succeeded.
    //
    // we pass the received token to the app's notification server then.
    func application(
      _ application: UIApplication,
      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let tokenString = tokenParts.joined()

        #if DEBUG
        let endpoint = "https://sandbox.notifications.delta.chat/register"
        #else
        let endpoint = "https://notifications.delta.chat/register"
        #endif

        logger.verbose("Notifications: POST token: \(tokenString) to \(endpoint)")

        if let url = URL(string: endpoint) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            let body = "{ \"token\": \"\(tokenString)\" }"
            request.httpBody = body.data(using: String.Encoding.utf8)
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    logger.error("Notifications: cannot POST to notification server: \(error)")
                    return
                }
                logger.info("Notifications: request to notification server succeeded with respose, data: \(String(describing: response)), \(String(describing: data))")
                self.notifyToken = tokenString

            }
            task.resume()
        } else {
            logger.error("Notifications: cannot create URL for token: \(tokenString)")
        }
    }

    // `didFailToRegisterForRemoteNotificationsWithError` is called by iOS
    // when the call to `UIApplication.shared.registerForRemoteNotifications` failed.
    func application(
      _ application: UIApplication,
      didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("Notifications: Failed to register: \(error)")
    }

    // `didReceiveRemoteNotification` is called by iOS when a push notification is received.
    //
    // we need to ensure IO is running as the function may be called from suspended state
    // (with app in memory, but gracefully shut down before; sort of freezed).
    // if the function was not called from suspended state,
    // the call to maybeStartIo() did nothing, therefore, interrupt and force fetch.
    //
    // we have max. 30 seconds time for our job and to call the completion handler.
    // as the system tracks the elapsed time, power usage, and data costs, we return faster,
    // after 10 seconds, things should be done.
    // (see https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623013-application)
    // (at some point it would be nice if we get a clear signal from the core)
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logger.verbose("Notifications: didReceiveRemoteNotification \(userInfo)")
        increaseDebugCounter("notify-remote-receive")
        let oldFresh = DcContext.shared.getFreshMessages().count

        dcContext.maybeStartIo()
        dcContext.maybeNetwork()

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if !self.appIsInForeground {
                self.dcContext.stopIo()
            }
            completionHandler(DcContext.shared.getFreshMessages().count > oldFresh ? .newData : .noData)
        }
    }

    private func increaseDebugCounter(_ name: String) {
        let nowDate = Date()
        let nowTimestamp = Double(nowDate.timeIntervalSince1970)
        let startTimestamp = UserDefaults.standard.double(forKey: name + "-start")
        if nowTimestamp > startTimestamp + 60*60*24 {
            let cal: Calendar = Calendar(identifier: .gregorian)
            let newStartDate: Date = cal.date(bySettingHour: 0, minute: 0, second: 0, of: nowDate)!
            UserDefaults.standard.set(0, forKey: name + "-count")
            UserDefaults.standard.set(Double(newStartDate.timeIntervalSince1970), forKey: name + "-start")
        }

        let cnt = UserDefaults.standard.integer(forKey: name + "-count")
        UserDefaults.standard.set(cnt + 1, forKey: name + "-count")
        UserDefaults.standard.set(nowTimestamp, forKey: name + "-last")
    }


    // MARK: - Handle notification banners

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

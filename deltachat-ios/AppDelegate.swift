import AudioToolbox
import Reachability
import SwiftyBeaver
import UIKit
import UserNotifications
import DcCore
import DBDebugToolkit
import SDWebImageWebPCoder
import Intents
import SDWebImageSVGKitPlugin

let logger = SwiftyBeaver.self

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let dcAccounts = DcAccounts()
    var appCoordinator: AppCoordinator!
    var relayHelper: RelayHelper!
    var locationManager: LocationManager!
    var notificationManager: NotificationManager!
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    var reachability = Reachability()!
    var window: UIWindow?
    var notifyToken: String?

    // purpose of `bgIoTimestamp` is to block rapidly subsequent calls to remote- or local-wakeups:
    //
    // `bgIoTimestamp` is set to last init, enter-background or last remote- or local-wakeup;
    // in the minute after these events, subsequent remote- or local-wakeups are skipped
    // in favor to the chance of being awakened when it makes more sense
    // and to avoid issues with calling concurrent series of startIo/maybeNetwork/stopIo.
    private var bgIoTimestamp: Double = 0.0


    // MARK: - app main entry point

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

        bgIoTimestamp = Double(Date().timeIntervalSince1970)

        DBDebugToolkit.setup(with: []) // empty array will override default device shake trigger
        DBDebugToolkit.setupCrashReporting()
        
        let console = ConsoleDestination()
        console.format = "$DHH:mm:ss.SSS$d $C$L$c $M" // see https://docs.swiftybeaver.com/article/20-custom-format
        logger.addDestination(console)

        dcAccounts.logger = DcLogger()
        dcAccounts.openDatabase()
        migrateToDcAccounts()

        if let sharedUserDefaults = UserDefaults.shared, !sharedUserDefaults.bool(forKey: UserDefaults.hasSavedKeyToKeychain) {
            // we can assume a fresh install (UserDefaults are deleted on app removal)
            // -> reset the keychain (which survives removals of the app) in case the app was removed and reinstalled.
            if !KeychainManager.deleteDBSecrets() {
                logger.warning("Failed to delete DB secrets")
            }
        }

        let accountIds = dcAccounts.getAll()
        for accountId in accountIds {
            let dcContext = dcAccounts.get(id: accountId)
            if !dcContext.isOpen() {
                do {
                    let secret = try KeychainManager.getAccountSecret(accountID: accountId)
                    if !dcContext.open(passphrase: secret) {
                        logger.error("Failed to open database for account \(accountId)")
                    }
                } catch KeychainError.unhandledError(let message, let status) {
                    logger.error("Keychain error. \(message). Error status: \(status)")
                } catch {
                    logger.error("\(error)")
                }
            }
        }

        if dcAccounts.getAll().isEmpty, dcAccounts.add() == 0 {
           fatalError("Could not initialize a new account.")
        }

        logger.info("➡️ didFinishLaunchingWithOptions")

        window = UIWindow(frame: UIScreen.main.bounds)
        guard let window = window else {
            fatalError("window was nil in app delegate")
        }
        if #available(iOS 13.0, *) {
            window.backgroundColor = UIColor.systemBackground
        } else {
            window.backgroundColor = UIColor.white
        }

        installEventHandler()
        relayHelper = RelayHelper.setup(dcAccounts.getSelected())
        appCoordinator = AppCoordinator(window: window, dcAccounts: dcAccounts)
        locationManager = LocationManager(dcAccounts: dcAccounts)
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        notificationManager = NotificationManager(dcAccounts: dcAccounts)
        dcAccounts.startIo()
        setStockTranslations()

        reachability.whenReachable = { reachability in
            // maybeNetwork() shall not be called in ui thread;
            // Reachability::reachabilityChanged uses DispatchQueue.main.async only
            logger.info("network: reachable", reachability.connection.description)
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.dcAccounts.maybeNetwork()
            }
        }

        reachability.whenUnreachable = { _ in
            logger.info("network: not reachable")
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.dcAccounts.maybeNetworkLost()
            }
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

        if dcAccounts.getSelected().isConfigured() && !UserDefaults.standard.bool(forKey: "notifications_disabled") {
            registerForNotifications()
        }

        let webPCoder = SDImageWebPCoder.shared
        SDImageCodersManager.shared.addCoder(webPCoder)
        let svgCoder = SDImageSVGKCoder.shared
        SDImageCodersManager.shared.addCoder(svgCoder)
        return true
    }

    // `open` is called when an url should be opened by Delta Chat.
    // we currently use that for handling oauth2 and for handing openpgp4fpr.
    //
    // before `open` gets called, `didFinishLaunchingWithOptions` is called.
    func application(_: UIApplication, open url: URL, options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        logger.info("➡️ open url")

        // gets here when app returns from oAuth2-Setup process - the url contains the provided token
        // if let params = url.queryParameters, let token = params["code"] {
        //    NotificationCenter.default.post(name: NSNotification.Name("oauthLoginApproved"), object: nil, userInfo: ["token": token])
        // }

        switch url.scheme?.lowercased() {
        case "openpgp4fpr":
            // Hack to format url properly
            let urlString = url.absoluteString
                           .replacingOccurrences(of: "openpgp4fpr", with: "OPENPGP4FPR", options: .literal, range: nil)
                           .replacingOccurrences(of: "%23", with: "#", options: .literal, range: nil)

            self.appCoordinator.handleQRCode(urlString)
            return true
        case "mailto":
            return self.appCoordinator.handleMailtoURL(url)
        default:
            return false
        }
    }


    // MARK: - app lifecycle

    func applicationWillEnterForeground(_: UIApplication) {
        logger.info("➡️ applicationWillEnterForeground")
        dcAccounts.startIo()

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            if self.reachability.connection != .none {
                self.dcAccounts.maybeNetwork()
            }

            if let userDefaults = UserDefaults.shared, userDefaults.bool(forKey: UserDefaults.hasExtensionAttemptedToSend) {
                userDefaults.removeObject(forKey: UserDefaults.hasExtensionAttemptedToSend)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: dcNotificationChanged,
                        object: nil,
                        userInfo: [:]
                    )
                }
            }
        }
    }

    func applicationWillResignActive(_: UIApplication) {
        logger.info("⬅️ applicationWillResignActive")
        registerBackgroundTask()
    }

    func applicationDidEnterBackground(_: UIApplication) {
        logger.info("⬅️ applicationDidEnterBackground")
    }

    func applicationWillTerminate(_: UIApplication) {
        logger.info("⬅️ applicationWillTerminate")
        dcAccounts.closeDatabase()
        reachability.stopNotifier()
    }


    // MARK: - fade out app smoothly

    // let the app run in background for a little while
    // eg. to complete sending messages out and to react to responses.
    private func registerBackgroundTask() {
        logger.info("⬅️ registering background task")
        bgIoTimestamp = Double(Date().timeIntervalSince1970)
        unregisterBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // usually, the background thread is finished before in maybeStop()
            logger.info("⬅️ background expirationHandler called")
            self?.unregisterBackgroundTask()
        }
        maybeStop()
    }

    private func unregisterBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    private func maybeStop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            let app = UIApplication.shared
            if app.applicationState != .background {
                logger.info("⬅️ no longer in background")
                self.unregisterBackgroundTask()
            } else if app.backgroundTimeRemaining < 10 {
                logger.info("⬅️ few background time, \(app.backgroundTimeRemaining), stopping")
                self.dcAccounts.stopIo()

                // to avoid 0xdead10cc exceptions, scheduled jobs need to be done before we get suspended;
                // we increase the probabilty that this happens by waiting a moment before calling unregisterBackgroundTask()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    logger.info("⬅️ few background time, \(app.backgroundTimeRemaining), done")
                    self.unregisterBackgroundTask()
                }
            } else {
                logger.info("⬅️ remaining background time: \(app.backgroundTimeRemaining)")
                self.maybeStop()
            }
        }
    }


    // MARK: - background fetch and notifications

    // `registerForNotifications` asks the user if they want to get notifiations shown.
    // if so, it registers for receiving remote notifications.
    func registerForNotifications() {
        UNUserNotificationCenter.current().delegate = self
        notifyToken = nil

        // register for showing notifications
        //
        // note: the alert-dialog cannot be customized, however, since iOS 12,
        // it can be avoided completely by using `.provisional`,
        // https://developer.apple.com/documentation/usernotifications/asking_permission_to_use_notifications
        UNUserNotificationCenter.current()
          .requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            if granted {
                // we are allowed to show notifications:
                // register for receiving remote notifications
                logger.info("Notifications: Permission granted: \(granted)")
                self?.maybeRegisterForRemoteNotifications()
            } else {
                logger.info("Notifications: Permission not granted.")
            }
        }
    }

    // register on apple server for receiving remote notifications
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

        logger.info("Notifications: POST token: \(tokenString) to \(endpoint)")

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
                if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode == 200 {
                    logger.info("Notifications: request to notification server succeeded")
                } else {
                    logger.error("Notifications: request to notification server failed: \(String(describing: response)), \(String(describing: data))")
                }
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

    // `didReceiveRemoteNotification` is called by iOS when a remote notification is received.
    //
    // we need to ensure IO is running as the function may be called from suspended state
    // (with app in memory, but gracefully shut down before; sort of freezed).
    // if the function was not called from suspended state,
    // the call to startIo() did nothing, therefore, interrupt and force fetch.
    //
    // we have max. 30 seconds time for our job and to call the completion handler.
    // as the system tracks the elapsed time, power usage, and data costs, we return faster,
    // after 10 seconds, things should be done.
    // (see https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623013-application)
    // (at some point it would be nice if we get a clear signal from the core)
    func application(
      _ application: UIApplication,
      didReceiveRemoteNotification userInfo: [AnyHashable: Any],
      fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        logger.info("➡️ Notifications: didReceiveRemoteNotification \(userInfo)")
        increaseDebugCounter("notify-remote-receive")
        performFetch(completionHandler: completionHandler)
    }

    // `performFetchWithCompletionHandler` is called by iOS on local wakeup.
    //
    // this requires "UIBackgroundModes: fetch" to be set in Info.plist
    // ("App downloads content from the network" in Xcode)
    //
    // we have 30 seconds time for our job, things are quite similar as in `didReceiveRemoteNotification`
    func application(
      _ application: UIApplication,
      performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        logger.info("➡️ Notifications: performFetchWithCompletionHandler")
        increaseDebugCounter("notify-local-wakeup")
        performFetch(completionHandler: completionHandler)
    }

    private func performFetch(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // `didReceiveRemoteNotification` as well as `performFetchWithCompletionHandler` might be called if we're in foreground,
        // in this case, there is no need to wait for things or do sth.
        if appIsInForeground() {
            logger.info("➡️ app already in foreground")
            completionHandler(.newData)
            return
        }

        // from time to time, `didReceiveRemoteNotification` and `performFetchWithCompletionHandler`
        // are actually called at the same millisecond.
        //
        // therefore, if last fetch is less than a minute ago, we skip this call;
        // this also lets the completionHandler being called earlier so that we maybe get awakened when it makes more sense.
        //
        // nb: calling the completion handler with .noData results in less calls overall.
        // if at some point we do per-message-push-notifications, we need to tweak this gate.
        let nowTimestamp = Double(Date().timeIntervalSince1970)
        if nowTimestamp < bgIoTimestamp + 60 {
            logger.info("➡️ fetch was just executed, skipping")
            completionHandler(.newData)
            return
        }
        bgIoTimestamp = nowTimestamp

        // make sure to balance each call to `beginBackgroundTask` with `endBackgroundTask`
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // usually, this handler is not used as we are taking care of timings below.
            logger.info("⬅️ finishing fetch by system urgency requests")
            self?.dcAccounts.stopIo()
            completionHandler(.newData)
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }

        // we're in background, run IO for a little time
        dcAccounts.startIo()
        dcAccounts.maybeNetwork()

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            logger.info("⬅️ finishing fetch")
            guard let self = self else {
                completionHandler(.failed)
                return
            }

            if !self.appIsInForeground() {
                self.dcAccounts.stopIo()
            }

            // to avoid 0xdead10cc exceptions, scheduled jobs need to be done before we get suspended;
            // we increase the probabilty that this happens by waiting a moment before calling completionHandler()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                logger.info("⬅️ fetch done")
                guard let self = self else {
                    completionHandler(.failed)
                    return
                }

                self.pushToDebugArray(name: "notify-fetch-durations", value: Double(Date().timeIntervalSince1970)-nowTimestamp)
                completionHandler(.newData)

                if backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                    backgroundTask = .invalid
                }
            }
        }
    }


    // MARK: - handle notification banners

    // This method will be called if an incoming message was received while the app was in foreground.
    // We don't show foreground notifications in the notification center because they don't get grouped properly
    func userNotificationCenter(_: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        logger.info("Notifications: foreground notification")
        completionHandler([.badge])
    }

    // this method will be called if the user tapped on a notification
    func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if !response.notification.request.identifier.containsExact(subSequence: Constants.notificationIdentifier).isEmpty {
            logger.info("Notifications: notification tapped")
            let userInfo = response.notification.request.content.userInfo
             if let chatId = userInfo["chat_id"] as? Int,
                 let msgId = userInfo["message_id"] as? Int {
                 if !appCoordinator.isShowingChat(chatId: chatId) {
                     appCoordinator.showChat(chatId: chatId, msgId: msgId, animated: false, clearViewControllerStack: true)
                 }
             }
        }

        completionHandler()
    }


    // MARK: - misc.

    func migrateToDcAccounts() {
        let dbHelper = DatabaseHelper()
        if let databaseLocation = dbHelper.unmanagedDatabaseLocation {
            if dcAccounts.migrate(dbLocation: databaseLocation) == 0 {
                 fatalError("Account could not be migrated")
                 // TODO: show error message in UI
            }
            INInteraction.deleteAll(completion: nil)
        }
    }

    func reloadDcContext() {
        setStockTranslations()
        locationManager.reloadDcContext()
        notificationManager.reloadDcContext()
        RelayHelper.sharedInstance.cancel()
        _ = RelayHelper.setup(dcAccounts.getSelected())
        if dcAccounts.getSelected().isConfigured() {
            appCoordinator.resetTabBarRootViewControllers()
        } else {
            appCoordinator.presentWelcomeController()
        }
    }

    func installEventHandler() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let eventHandler = DcEventHandler(dcAccounts: self.dcAccounts)
            let eventEmitter = self.dcAccounts.getEventEmitter()
            while true {
                guard let event = eventEmitter.getNextEvent() else { break }
                eventHandler.handleEvent(event: event)
            }
            logger.info("⬅️ event emitter finished")
        }
    }

    private func increaseDebugCounter(_ name: String) {
        let nowDate = Date()
        let nowTimestamp = Double(nowDate.timeIntervalSince1970)
        // Values calculated for debug log view
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

        // Values calculated for connectivity view
        if name == "notify-remote-receive" || name == "notify-local-wakeup" {
            let timestamps = UserDefaults.standard.array(forKey: Constants.Keys.notificationTimestamps)
            var slidingTimeframe: [Double]
            if timestamps != nil, let timestamps = timestamps as? [Double] {
                slidingTimeframe = timestamps.filter({ nowTimestamp < $0 + 60 * 60 * 24 })
            } else {
                slidingTimeframe = [Double]()
            }
            slidingTimeframe.append(nowTimestamp)
            UserDefaults.standard.set(slidingTimeframe, forKey: Constants.Keys.notificationTimestamps)
        }
    }

    private func pushToDebugArray(name: String, value: Double) {
        let values = UserDefaults.standard.array(forKey: name)
        var slidingValues = [Double]()
        if values != nil, let values = values as? [Double] {
            slidingValues = values.suffix(16)
        }
        slidingValues.append(value)
        UserDefaults.standard.set(slidingValues, forKey: name)
    }

    private func setStockTranslations() {
        let dcContext = dcAccounts.getSelected()
        dcContext.setStockTranslation(id: DC_STR_NOMESSAGES, localizationKey: "chat_no_messages")
        dcContext.setStockTranslation(id: DC_STR_SELF, localizationKey: "self")
        dcContext.setStockTranslation(id: DC_STR_DRAFT, localizationKey: "draft")
        dcContext.setStockTranslation(id: DC_STR_VOICEMESSAGE, localizationKey: "voice_message")
        dcContext.setStockTranslation(id: DC_STR_IMAGE, localizationKey: "image")
        dcContext.setStockTranslation(id: DC_STR_VIDEO, localizationKey: "video")
        dcContext.setStockTranslation(id: DC_STR_AUDIO, localizationKey: "audio")
        dcContext.setStockTranslation(id: DC_STR_FILE, localizationKey: "file")
        //dcContext.setStockTranslation(id: DC_STR_STATUSLINE, localizationKey: "pref_default_status_text")
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
        dcContext.setStockTranslation(id: DC_STR_MSGACTIONBYUSER, localizationKey: "systemmsg_action_by_user")
        dcContext.setStockTranslation(id: DC_STR_MSGACTIONBYME, localizationKey: "systemmsg_action_by_me")
        dcContext.setStockTranslation(id: DC_STR_LOCATION, localizationKey: "location")
        dcContext.setStockTranslation(id: DC_STR_STICKER, localizationKey: "sticker")
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
        dcContext.setStockTranslation(id: DC_STR_VIDEOCHAT_INVITATION, localizationKey: "videochat_invitation")
        dcContext.setStockTranslation(id: DC_STR_VIDEOCHAT_INVITE_MSG_BODY, localizationKey: "videochat_invitation_body")
        dcContext.setStockTranslation(id: DC_STR_CONFIGURATION_FAILED, localizationKey: "configuration_failed_with_error")
        dcContext.setStockTranslation(id: DC_STR_BAD_TIME_MSG_BODY, localizationKey: "devicemsg_bad_time")
        dcContext.setStockTranslation(id: DC_STR_UPDATE_REMINDER_MSG_BODY, localizationKey: "devicemsg_update_reminder")
        dcContext.setStockTranslation(id: DC_STR_PROTECTION_ENABLED, localizationKey: "systemmsg_chat_protection_enabled")
        dcContext.setStockTranslation(id: DC_STR_PROTECTION_DISABLED, localizationKey: "systemmsg_chat_protection_disabled")
        dcContext.setStockTranslation(id: DC_STR_REPLY_NOUN, localizationKey: "reply_noun")
        dcContext.setStockTranslation(id: DC_STR_SELF_DELETED_MSG_BODY, localizationKey: "devicemsg_self_deleted")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_MINUTES, localizationKey: "systemmsg_ephemeral_timer_minutes")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_HOURS, localizationKey: "systemmsg_ephemeral_timer_hours")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_DAYS, localizationKey: "systemmsg_ephemeral_timer_days")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_WEEKS, localizationKey: "systemmsg_ephemeral_timer_weeks")
        dcContext.setStockTranslation(id: DC_STR_FORWARDED, localizationKey: "forwarded")
        dcContext.setStockTranslation(id: DC_STR_QUOTA_EXCEEDING_MSG_BODY, localizationKey: "devicemsg_storage_exceeding")
        dcContext.setStockTranslation(id: DC_STR_PARTIAL_DOWNLOAD_MSG_BODY, localizationKey: "n_bytes_message")
        dcContext.setStockTranslation(id: DC_STR_DOWNLOAD_AVAILABILITY, localizationKey: "download_max_available_until")
        dcContext.setStockTranslation(id: DC_STR_INCOMING_MESSAGES, localizationKey: "incoming_messages")
        dcContext.setStockTranslation(id: DC_STR_OUTGOING_MESSAGES, localizationKey: "outgoing_messages")
        dcContext.setStockTranslation(id: DC_STR_STORAGE_ON_DOMAIN, localizationKey: "storage_on_domain")
        dcContext.setStockTranslation(id: DC_STR_ONE_MOMENT, localizationKey: "one_moment")
        dcContext.setStockTranslation(id: DC_STR_CONNECTED, localizationKey: "connectivity_connected")
        dcContext.setStockTranslation(id: DC_STR_CONNTECTING, localizationKey: "connectivity_connecting")
        dcContext.setStockTranslation(id: DC_STR_UPDATING, localizationKey: "connectivity_updating")
        dcContext.setStockTranslation(id: DC_STR_SENDING, localizationKey: "sending")
        dcContext.setStockTranslation(id: DC_STR_LAST_MSG_SENT_SUCCESSFULLY, localizationKey: "last_msg_sent_successfully")
        dcContext.setStockTranslation(id: DC_STR_ERROR, localizationKey: "error_x")
        dcContext.setStockTranslation(id: DC_STR_NOT_SUPPORTED_BY_PROVIDER, localizationKey: "not_supported_by_provider")
        dcContext.setStockTranslation(id: DC_STR_MESSAGES, localizationKey: "messages")
        dcContext.setStockTranslation(id: DC_STR_BROADCAST_LIST, localizationKey: "broadcast_list")
        dcContext.setStockTranslation(id: DC_STR_PART_OF_TOTAL_USED, localizationKey: "part_of_total_used")
        dcContext.setStockTranslation(id: DC_STR_SECURE_JOIN_STARTED, localizationKey: "secure_join_started")
        dcContext.setStockTranslation(id: DC_STR_SECURE_JOIN_REPLIES, localizationKey: "secure_join_replies")
        dcContext.setStockTranslation(id: DC_STR_SETUP_CONTACT_QR_DESC, localizationKey: "qrshow_join_contact_hint")
        dcContext.setStockTranslation(id: DC_STR_SECURE_JOIN_GROUP_QR_DESC, localizationKey: "qrshow_join_group_hint")
    }

    func appIsInForeground() -> Bool {
        switch UIApplication.shared.applicationState {
        case .background, .inactive:
            return false
        case .active:
            return true
        }
    }
}

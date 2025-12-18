import AudioToolbox
import Reachability
import UIKit
import UserNotifications
import DcCore
import SDWebImageWebPCoder
import Intents
import SDWebImageSVGKitPlugin

let logger = getDcLogger()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let dcAccounts = DcAccounts.shared
    var appCoordinator: AppCoordinator!
    var relayHelper: RelayHelper!
    var locationManager: LocationManager!
    var notificationManager: NotificationManager!
    var callManager: CallManager?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    var reachability: Reachability?
    var window: UIWindow?
    var callWindow: CallWindow!
    var notifyToken: String?
    var applicationInForeground: Bool = false
    private var launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    private var appFullyInitialized = false

    // purpose of `bgIoTimestamp` is to block rapidly subsequent calls to remote- or local-wakeups:
    //
    // `bgIoTimestamp` is set to enter-background or last remote- or local-wakeup;
    // in the minute after these events, subsequent remote- or local-wakeups are skipped
    // in favor to the chance of being awakened when it makes more sense
    // and to avoid issues with calling concurrent series of startIo/maybeNetwork/stopIo.
    private var bgIoTimestamp: Double = 0.0

    /// Other processes like the Notification Service Extension can post
    /// DarwinNotification.appRunningQuestion in which case we reply with .appRunningConfirmation
    @objc func appRunningQuestion(notification: DarwinNotification) {
        guard UserDefaults.mainIoRunning else { return }
        DarwinNotificationCenter.current.post(.appRunningConfirmation)
    }

    // MARK: - app main entry point

    // `didFinishLaunchingWithOptions` is the main entry point
    // that is called if the app is started for the first time
    // or after the app is killed.
    //
    // - `didFinishLaunchingWithOptions` is also called before event methods as `didReceiveRemoteNotification` are called -
    //   either _directly before_ (if the app was killed) or _long before_ (if the app was suspended).
    //
    // - in some cases `didFinishLaunchingWithOptions` is called _instead_ an event method and `launchOptions` tells the reason;
    //   the event method may or may not be called in this case, see #1542 for some deeper information.
    //
    // `didFinishLaunchingWithOptions` is _not_ called
    // when the app wakes up from "suspended" state
    // (app is in memory in the background but no code is executed, IO stopped)
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // explicitly ignore SIGPIPE to avoid crashes, see https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/NetworkingOverview/CommonPitfalls/CommonPitfalls.html
        // setupCrashReporting() may create an additional handler, but we do not want to rely on that
        signal(SIGPIPE, SIG_IGN)

        logger.info("➡️ didFinishLaunchingWithOptions")
        DarwinNotificationCenter.current.addObserver(self, selector: #selector(Self.appRunningQuestion), for: .appRunningQuestion)
        callManager = CallManager.shared
        UserDefaults.standard.populateDefaultEmojis()
        UserDefaults.setMainIoRunning()
        UNUserNotificationCenter.current().delegate = self

        let webPCoder = SDImageWebPCoder.shared
        SDImageCodersManager.shared.addCoder(webPCoder)
        let svgCoder = SDImageSVGKCoder.shared
        SDImageCodersManager.shared.addCoder(svgCoder)

        dcAccounts.openDatabase(writeable: true)
        migrateToDcAccounts()

        self.launchOptions = launchOptions
        continueDidFinishLaunchingWithOptions()
        return true
    }

    // finishes the app initialization which depends on the successful access to the keychain
    func continueDidFinishLaunchingWithOptions() {
        if let sharedUserDefaults = UserDefaults.shared, !sharedUserDefaults.bool(forKey: UserDefaults.hasSavedKeyToKeychain) {
            // we can assume a fresh install (UserDefaults are deleted on app removal)
            // -> reset the keychain (which survives removals of the app) in case the app was removed and reinstalled.
            if !KeychainManager.deleteDBSecrets() {
                logger.warning("Failed to delete DB secrets")
            }
        }

        do {
            self.reachability = try Reachability()
        } catch {
            // TODO: Handle
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
                } catch KeychainError.accessError(let message, let status) {
                    logger.error("Keychain error. \(message). Error status: \(status)")
                    return
                } catch KeychainError.unhandledError(let message, let status) {
                    logger.error("Keychain error. \(message). Error status: \(status)")
                } catch {
                    logger.error("\(error)")
                }
            }

            // migration 2025-12-18: the option was removed, reverting to default
            dcContext.setConfigInt("webxdc_realtime_enabled", 1)
            // /migration 2025-12-18

            // migration 2025-11-28: needed until core starts ignoring "delete_server_after" for chatmail or drops the setting at all
            if dcContext.isChatmail {
                dcContext.setConfig("delete_server_after", nil) // reset - let core decide based on bcc_self aka "Multi-Transport Mode"
            }
            // /migration 2025-11-28
        }

        if dcAccounts.getAll().isEmpty, dcAccounts.add() == 0 {
           fatalError("Could not initialize a new account.")
        }

        window = UIWindow(frame: UIScreen.main.bounds)
        guard let window = window else {
            fatalError("window was nil in app delegate")
        }
        window.backgroundColor = UIColor.systemBackground
        callWindow = CallWindow(frame: UIScreen.main.bounds)
        installEventHandler()
        relayHelper = RelayHelper.setup(dcAccounts.getSelected())
        appCoordinator = AppCoordinator(window: window, dcAccounts: dcAccounts)
        locationManager = LocationManager(dcAccounts: dcAccounts)
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        notificationManager = NotificationManager(dcAccounts: dcAccounts)
        setStockTranslations()
        dcAccounts.startIo()

        if let reachability {
            reachability.whenReachable = { reachability in
                // maybeNetwork() shall not be called in ui thread;
                // Reachability::reachabilityChanged uses DispatchQueue.main.async only
                logger.info("network: reachable \(reachability.connection.description)")
                DispatchQueue.global().async { [weak self] in
                    guard let self else { return }
                    self.dcAccounts.maybeNetwork()
                    if self.notifyToken == nil && self.dcAccounts.getSelected().isConfigured() {
                        self.registerForNotifications()
                        self.prepopulateWidget()
                    }
                }
            }

            reachability.whenUnreachable = { _ in
                logger.info("network: not reachable")
                DispatchQueue.global().async { [weak self] in
                    self?.dcAccounts.maybeNetworkLost()
                }
            }

            do {
                try reachability.startNotifier()
            } catch {
                logger.error("Unable to start notifier")
            }
        }

        if let notificationOption = launchOptions?[.remoteNotification] {
            logger.info("Notifications: remoteNotification: \(String(describing: notificationOption))")
            UserDefaults.pushToDebugArray("📡'")
            performFetch()
        }

        if dcAccounts.getSelected().isConfigured() {
            registerForNotifications()
            prepopulateWidget()
        }

        launchOptions = nil
        appFullyInitialized = true
    }

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let incomingURL = userActivity.webpageURL,
           let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true),
           let host = components.host {
            logger.info("➡️ open univeral link url")

            if host == Utils.inviteDomain {
                appCoordinator.handleQRCode(incomingURL.absoluteString)
                return true
            } else {
                return false
            }
        } else if userActivity.interaction?.intent is INStartAudioCallIntent {
            logger.info("➡️ INStartAudioCallIntent")
            return false
        } else {
            return false
        }
    }

    // `open` is called when an url should be opened by Delta Chat.
    // we currently use that for handing openpgp4fpr.
    //
    // before `open` gets called, `didFinishLaunchingWithOptions` is called.
    func application(_: UIApplication, open url: URL, options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        logger.info("➡️ open url")

        switch url.scheme?.lowercased() {
        case "dcaccount", "dclogin",
             "https" where url.host == Utils.inviteDomain:
            appCoordinator.handleQRCode(url.absoluteString)
            return true
        case "openpgp4fpr":
            // Hack to format url properly
            let urlString = url.absoluteString
                           .replacingOccurrences(of: "openpgp4fpr", with: "OPENPGP4FPR", options: .literal, range: nil)
                           .replacingOccurrences(of: "%23", with: "#", options: .literal, range: nil)

            appCoordinator.handleQRCode(urlString)
            return true
        case "mailto":
            return appCoordinator.handleMailtoURL(url)
        case "chat.delta.deeplink":
            return appCoordinator.handleDeepLinkURL(url)
        default:
            return false
        }
    }


    // MARK: - app lifecycle

    // applicationWillEnterForeground() is _not_ called on initial app start
    func applicationWillEnterForeground(_: UIApplication) {
        logger.info("➡️ applicationWillEnterForeground")
        applicationInForeground = true
        UserDefaults.setMainIoRunning()
        dcAccounts.startIo()

        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            if let reachability = self.reachability {
                if reachability.connection != .unavailable {
                    self.dcAccounts.maybeNetwork()
                }
            }

            AppDelegate.emitMsgsChangedIfShareExtensionWasUsed()
        }
    }

    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        logger.info("➡️ applicationProtectedDataDidBecomeAvailable")
        if !appFullyInitialized {
            continueDidFinishLaunchingWithOptions()
        }
    }

    func applicationProtectedDataWillBecomeUnavailable(_ application: UIApplication) {
        logger.info("⬅️ applicationProtectedDataWillBecomeUnavailable")
    }

    static func emitMsgsChangedIfShareExtensionWasUsed() {
        if let userDefaults = UserDefaults.shared, userDefaults.bool(forKey: UserDefaults.hasExtensionAttemptedToSend) {
            userDefaults.removeObject(forKey: UserDefaults.hasExtensionAttemptedToSend)

            NotificationCenter.default.post(name: Event.messagesChanged, object: nil, userInfo: [
                "message_id": Int(0),
                "chat_id": Int(0),
            ])
        }
    }

    // applicationDidBecomeActive() is called on initial app start _and_ after applicationWillEnterForeground()
    func applicationDidBecomeActive(_: UIApplication) {
        logger.info("➡️ applicationDidBecomeActive")
        UserDefaults.setMainIoRunning()
        applicationInForeground = true
        NotificationManager.updateBadgeCounters()
    }

    func applicationWillResignActive(_: UIApplication) {
        logger.info("⬅️ applicationWillResignActive")
        registerBackgroundTask()
    }

    func applicationDidEnterBackground(_: UIApplication) {
        logger.info("⬅️ applicationDidEnterBackground")
        applicationInForeground = false
    }

    func applicationWillTerminate(_: UIApplication) {
        logger.info("⬅️ applicationWillTerminate")
        uninstallEventHandler()
        dcAccounts.closeDatabase()
        if let reachability = reachability {
            reachability.stopNotifier()
        }
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
                UserDefaults.setMainIoRunning(false)

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

    // asks the user if they want to get notifications shown.
    // nb: the alert dialog could be avoided by using `.provisional`,
    // https://developer.apple.com/documentation/usernotifications/asking_permission_to_use_notifications
    func registerForNotifications() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.notifyToken = nil
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                DispatchQueue.main.async {
                    if !granted || error != nil {
                        logger.warning("Notifications: Permission not granted, \(error?.localizedDescription ?? "no error")")
                    } else {
                        logger.info("Notifications: Permission granted")
                        // register on apple's server for notifications: we get the needed token in `didRegisterForRemoteNotificationsWithDeviceToken`
                        // or an error in `didFailToRegisterForRemoteNotificationsWithError`
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        }
    }

    public func prepopulateWidget() {
        if #available(iOS 17.0, *) {
            UserDefaults.shared?.prepopulateWidget()
        }
    }

    // `didRegisterForRemoteNotificationsWithDeviceToken` is called by iOS
    // when the call to `UIApplication.shared.registerForRemoteNotifications` succeeded.
    //
    // we pass the received token to the app's notification server then.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        #if DEBUG
            let notifyToken = "sandbox:" + tokenParts.joined()
        #else
            let notifyToken = tokenParts.joined()
        #endif
        logger.info("Notifications: Token: \(notifyToken)")
        self.notifyToken = notifyToken
        dcAccounts.setPushToken(token: notifyToken)
    }

    // `didFailToRegisterForRemoteNotificationsWithError` is called by iOS
    // when the call to `UIApplication.shared.registerForRemoteNotifications` failed.
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
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
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logger.info("➡️ Notifications: didReceiveRemoteNotification \(userInfo)")
        UserDefaults.pushToDebugArray("📡")
        performFetch(completionHandler: completionHandler)
    }

    // `performFetchWithCompletionHandler` is called by iOS on local wakeup.
    //
    // this requires "UIBackgroundModes: fetch" to be set in Info.plist
    // ("App downloads content from the network" in Xcode)
    //
    // we have 30 seconds time for our job, things are quite similar as in `didReceiveRemoteNotification`
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logger.info("➡️ Notifications: performFetchWithCompletionHandler")
        UserDefaults.pushToDebugArray("🏠")
        performFetch(completionHandler: completionHandler)
    }

    private func performFetch(completionHandler: ((UIBackgroundFetchResult) -> Void)? = nil) {
        // `didReceiveRemoteNotification` and`performFetchWithCompletionHandler` might be called if we're fetching instantly in foreground already
        if appIsInForeground() {
            logger.info("➡️ app already in foreground")
            UserDefaults.pushToDebugArray("ABORT1_APP_IN_FG")
            completionHandler?(.newData)
            return
        }

        // abort if NSE is runnig; core cannot start I/O twice
        if UserDefaults.nseFetching {
            logger.info("➡️ NSE already running")
            UserDefaults.pushToDebugArray("ABORT2_NSE_RUNNING")
            completionHandler?(.newData)
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
            UserDefaults.pushToDebugArray("ABORT3_SKIP")
            completionHandler?(.newData)
            return
        }
        bgIoTimestamp = nowTimestamp

        // make sure to balance each call to `beginBackgroundTask` with `endBackgroundTask`
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // usually, this handler is not used as we are taking care of timings below.
            logger.info("⬅️ finishing fetch by system urgency requests")
            UserDefaults.pushToDebugArray("ERR1_URGENCY")
            self?.dcAccounts.stopIo()
            UserDefaults.setMainIoRunning(false)
            completionHandler?(.newData)
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }

        // move work to non-main thread to not block UI (otherwise, in case we get suspended, the app is blocked totally)
        // (we are using `qos: default` as `qos: .background` may be delayed by tens of minutes)
        DispatchQueue.global().async { [weak self] in
            guard let self else { completionHandler?(.failed); return }

            self.addDebugFetchTimestamp()
            self.dcAccounts.fetchSemaphore = DispatchSemaphore(value: 0)

            // backgroundFetch() pauses IO as needed
            UserDefaults.setMainIoRunning()

            if !self.dcAccounts.backgroundFetch(timeout: 20) {
                logger.error("backgroundFetch failed")
                UserDefaults.self.pushToDebugArray("ERR2_CORE")
            }

            if !appIsInForeground() {
                UserDefaults.setMainIoRunning(false) // this also improves resilience: if we crashed before, NSE would never run otherwise
            }

            // wait for DC_EVENT_ACCOUNTS_BACKGROUND_FETCH_DONE;
            // without IO being started, more events that could interfere with shutdown are not added
            _ = self.dcAccounts.fetchSemaphore?.wait(timeout: .now() + 20)
            self.dcAccounts.fetchSemaphore = nil

            let diff = Double(Date().timeIntervalSince1970) - nowTimestamp
            logger.info("⬅️ finishing fetch in \(diff) s")

            // to avoid 0xdead10cc exceptions, scheduled jobs need to be done before we get suspended;
            // we increase the probabilty that this happens by waiting a moment before calling completionHandler()
            usleep(1_000_000)
            logger.info("⬅️ fetch done")

            UserDefaults.pushToDebugArray(String(format: "OK3 %.3fs", diff))
            completionHandler?(.newData)
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }
    }


    // MARK: - handle notification banners

    // This method will be called if an incoming message was received while the app was in foreground.
    // We don't show foreground notifications in the notification center because they don't get grouped properly
    func userNotificationCenter(_: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // The foreground check is necessary as this function is called when in app switcher
        if appIsInForeground(), notification.request.content.userInfo["answer_call"] == nil {
            logger.info("Notifications: foreground notification")
            completionHandler([.badge])
        } else {
            completionHandler([.badge, .banner, .list, .sound])
        }
    }

    // this method will be called if the user tapped on a notification
    func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let accountId = userInfo["account_id"] as? Int {
            let prevAccountId = dcAccounts.getSelected().id
            if accountId != prevAccountId {
                if !dcAccounts.select(id: accountId) {
                    completionHandler()
                    return
                }
                UserDefaults.standard.setValue(prevAccountId, forKey: Constants.Keys.lastSelectedAccountKey)
                reloadDcContext()
            }

            if userInfo["open_as_overview"] as? Bool ?? false {
                appCoordinator.popTabsToRootViewControllers()
                appCoordinator.showTab(index: appCoordinator.chatsTab)
            } else if let chatId = userInfo["chat_id"] as? Int, !appCoordinator.isShowingChat(chatId: chatId) {
                appCoordinator.showChat(chatId: chatId, msgId: userInfo["message_id"] as? Int, animated: false, clearViewControllerStack: true)
            }
            if let call = userInfo["answer_call"] as? String, let uuid = UUID(uuidString: call) {
                CallManager.shared.answerIncomingCall(withUUID: uuid)
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

    /// - Parameters:
    ///   - accountCode: optional string representation of dcaccounts: url, used to setup a new account
    func reloadDcContext(accountCode: String? = nil) {
        setStockTranslations()
        locationManager.reloadDcContext()
        notificationManager.reloadDcContext()
        RelayHelper.shared.finishRelaying()
        _ = RelayHelper.setup(dcAccounts.getSelected())
        if dcAccounts.getSelected().isConfigured() {
            appCoordinator.resetTabBarRootViewControllers()
        } else {
            appCoordinator.presentWelcomeController(accountCode: accountCode)
        }
    }

    private var shouldShutdownEventLoop = false
    private var eventHandlerActive = false
    private var eventShutdownSemaphore = DispatchSemaphore(value: 0)

    private func installEventHandler() {
        if eventHandlerActive {
            return
        }
        eventHandlerActive = true
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let eventHandler = DcEventHandler(dcAccounts: self.dcAccounts)
            let eventEmitter = self.dcAccounts.getEventEmitter()
            logger.info("➡️ event emitter started")
            while !shouldShutdownEventLoop {
                guard let event = eventEmitter.getNextEvent() else { break }
                eventHandler.handleEvent(event: event)
            }
            logger.info("⬅️ event emitter finished")
            eventShutdownSemaphore.signal()
            eventHandlerActive = false
        }
    }

    private func uninstallEventHandler() {
        shouldShutdownEventLoop = true
        dcAccounts.stopIo() // stopIo will generate atleast one event to the event handler can shut down
        UserDefaults.setMainIoRunning(false)
        eventShutdownSemaphore.wait()
        shouldShutdownEventLoop = false
    }

    // Values calculated for connectivity view
    private func addDebugFetchTimestamp() {
        let nowTimestamp = Double(Date().timeIntervalSince1970)
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
        dcContext.setStockTranslation(id: DC_STR_GIF, localizationKey: "gif")
        dcContext.setStockTranslation(id: DC_STR_CONTACT_VERIFIED, localizationKey: "contact_verified")
        dcContext.setStockTranslation(id: DC_STR_ARCHIVEDCHATS, localizationKey: "chat_archived_label")
        dcContext.setStockTranslation(id: DC_STR_CANNOT_LOGIN, localizationKey: "login_error_cannot_login")
        dcContext.setStockTranslation(id: DC_STR_LOCATION, localizationKey: "location")
        dcContext.setStockTranslation(id: DC_STR_STICKER, localizationKey: "sticker")
        dcContext.setStockTranslation(id: DC_STR_DEVICE_MESSAGES, localizationKey: "device_talk")
        dcContext.setStockTranslation(id: DC_STR_SAVED_MESSAGES, localizationKey: "saved_messages")
        dcContext.setStockTranslation(id: DC_STR_DEVICE_MESSAGES_HINT, localizationKey: "device_talk_explain")
        dcContext.setStockTranslation(id: DC_STR_WELCOME_MESSAGE, localizationKey: "device_talk_welcome_message2")
        dcContext.setStockTranslation(id: DC_STR_SUBJECT_FOR_NEW_CONTACT, localizationKey: "systemmsg_subject_for_new_contact")
        dcContext.setStockTranslation(id: DC_STR_FAILED_SENDING_TO, localizationKey: "systemmsg_failed_sending_to")
        dcContext.setStockTranslation(id: DC_STR_CONFIGURATION_FAILED, localizationKey: "configuration_failed_with_error")
        dcContext.setStockTranslation(id: DC_STR_BAD_TIME_MSG_BODY, localizationKey: "devicemsg_bad_time")
        dcContext.setStockTranslation(id: DC_STR_UPDATE_REMINDER_MSG_BODY, localizationKey: "devicemsg_update_reminder")
        dcContext.setStockTranslation(id: DC_STR_REPLY_NOUN, localizationKey: "reply_noun")
        dcContext.setStockTranslation(id: DC_STR_SELF_DELETED_MSG_BODY, localizationKey: "devicemsg_self_deleted")
        dcContext.setStockTranslation(id: DC_STR_FORWARDED, localizationKey: "forwarded")
        dcContext.setStockTranslation(id: DC_STR_QUOTA_EXCEEDING_MSG_BODY, localizationKey: "devicemsg_storage_exceeding")
        dcContext.setStockTranslation(id: DC_STR_PARTIAL_DOWNLOAD_MSG_BODY, localizationKey: "n_bytes_message")
        dcContext.setStockTranslation(id: DC_STR_DOWNLOAD_AVAILABILITY, localizationKey: "download_max_available_until")
        dcContext.setStockTranslation(id: DC_STR_INCOMING_MESSAGES, localizationKey: "incoming_messages")
        dcContext.setStockTranslation(id: DC_STR_OUTGOING_MESSAGES, localizationKey: "outgoing_messages")
        dcContext.setStockTranslation(id: DC_STR_STORAGE_ON_DOMAIN, localizationKey: "storage_on_domain")
        dcContext.setStockTranslation(id: DC_STR_CONNECTED, localizationKey: "connectivity_connected")
        dcContext.setStockTranslation(id: DC_STR_CONNTECTING, localizationKey: "connectivity_connecting")
        dcContext.setStockTranslation(id: DC_STR_UPDATING, localizationKey: "connectivity_updating")
        dcContext.setStockTranslation(id: DC_STR_SENDING, localizationKey: "sending")
        dcContext.setStockTranslation(id: DC_STR_LAST_MSG_SENT_SUCCESSFULLY, localizationKey: "last_msg_sent_successfully")
        dcContext.setStockTranslation(id: DC_STR_ERROR, localizationKey: "error_x")
        dcContext.setStockTranslation(id: DC_STR_NOT_SUPPORTED_BY_PROVIDER, localizationKey: "not_supported_by_provider")
        dcContext.setStockTranslation(id: DC_STR_MESSAGES, localizationKey: "messages")
        dcContext.setStockTranslation(id: DC_STR_PART_OF_TOTAL_USED, localizationKey: "part_of_total_used")
        dcContext.setStockTranslation(id: DC_STR_SECURE_JOIN_STARTED, localizationKey: "secure_join_started")
        dcContext.setStockTranslation(id: DC_STR_SECURE_JOIN_REPLIES, localizationKey: "secure_join_replies")
        dcContext.setStockTranslation(id: DC_STR_SETUP_CONTACT_QR_DESC, localizationKey: "qrshow_join_contact_hint")
        dcContext.setStockTranslation(id: DC_STR_SECURE_JOIN_GROUP_QR_DESC, localizationKey: "qrshow_join_group_hint")
        dcContext.setStockTranslation(id: DC_STR_NOT_CONNECTED, localizationKey: "connectivity_not_connected")
        dcContext.setStockTranslation(id: DC_STR_GROUP_NAME_CHANGED_BY_YOU, localizationKey: "group_name_changed_by_you")
        dcContext.setStockTranslation(id: DC_STR_GROUP_NAME_CHANGED_BY_OTHER, localizationKey: "group_name_changed_by_other")
        dcContext.setStockTranslation(id: DC_STR_GROUP_IMAGE_CHANGED_BY_YOU, localizationKey: "group_image_changed_by_you")
        dcContext.setStockTranslation(id: DC_STR_GROUP_IMAGE_CHANGED_BY_OTHER, localizationKey: "group_image_changed_by_other")
        dcContext.setStockTranslation(id: DC_STR_ADD_MEMBER_BY_YOU, localizationKey: "add_member_by_you")
        dcContext.setStockTranslation(id: DC_STR_ADD_MEMBER_BY_OTHER, localizationKey: "add_member_by_other")
        dcContext.setStockTranslation(id: DC_STR_REMOVE_MEMBER_BY_YOU, localizationKey: "remove_member_by_you")
        dcContext.setStockTranslation(id: DC_STR_REMOVE_MEMBER_BY_OTHER, localizationKey: "remove_member_by_other")
        dcContext.setStockTranslation(id: DC_STR_GROUP_LEFT_BY_YOU, localizationKey: "group_left_by_you")
        dcContext.setStockTranslation(id: DC_STR_GROUP_LEFT_BY_OTHER, localizationKey: "group_left_by_other")
        dcContext.setStockTranslation(id: DC_STR_GROUP_IMAGE_DELETED_BY_YOU, localizationKey: "group_image_deleted_by_you")
        dcContext.setStockTranslation(id: DC_STR_GROUP_IMAGE_DELETED_BY_OTHER, localizationKey: "group_image_deleted_by_other")
        dcContext.setStockTranslation(id: DC_STR_LOCATION_ENABLED_BY_YOU, localizationKey: "location_enabled_by_you")
        dcContext.setStockTranslation(id: DC_STR_LOCATION_ENABLED_BY_OTHER, localizationKey: "location_enabled_by_other")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_DISABLED_BY_YOU, localizationKey: "ephemeral_timer_disabled_by_you")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_DISABLED_BY_OTHER, localizationKey: "ephemeral_timer_disabled_by_other")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_SECONDS_BY_YOU, localizationKey: "ephemeral_timer_seconds_by_you")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_SECONDS_BY_OTHER, localizationKey: "ephemeral_timer_seconds_by_other")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_1_HOUR_BY_YOU, localizationKey: "ephemeral_timer_1_hour_by_you")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_1_HOUR_BY_OTHER, localizationKey: "ephemeral_timer_1_hour_by_other")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_1_DAY_BY_YOU, localizationKey: "ephemeral_timer_1_day_by_you")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_1_DAY_BY_OTHER, localizationKey: "ephemeral_timer_1_day_by_other")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_1_WEEK_BY_YOU, localizationKey: "ephemeral_timer_1_week_by_you")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_1_WEEK_BY_OTHER, localizationKey: "ephemeral_timer_1_week_by_other")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_MINUTES_BY_YOU, localizationKey: "ephemeral_timer_minutes_by_you")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_MINUTES_BY_OTHER, localizationKey: "ephemeral_timer_minutes_by_other")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_HOURS_BY_YOU, localizationKey: "ephemeral_timer_hours_by_you")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_HOURS_BY_OTHER, localizationKey: "ephemeral_timer_hours_by_other")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_DAYS_BY_YOU, localizationKey: "ephemeral_timer_days_by_you")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_DAYS_BY_OTHER, localizationKey: "ephemeral_timer_days_by_other")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_WEEKS_BY_YOU, localizationKey: "ephemeral_timer_weeks_by_you")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_WEEKS_BY_OTHER, localizationKey: "ephemeral_timer_weeks_by_other")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_1_YEAR_BY_YOU, localizationKey: "ephemeral_timer_1_year_by_you")
        dcContext.setStockTranslation(id: DC_STR_EPHEMERAL_TIMER_1_YEAR_BY_OTHER, localizationKey: "ephemeral_timer_1_year_by_other")
        dcContext.setStockTranslation(id: DC_STR_BACKUP_TRANSFER_QR, localizationKey: "multidevice_qr_subtitle")
        dcContext.setStockTranslation(id: DC_STR_BACKUP_TRANSFER_MSG_BODY, localizationKey: "multidevice_transfer_done_devicemsg")
        dcContext.setStockTranslation(id: DC_STR_CHAT_PROTECTION_ENABLED, localizationKey: "chat_protection_enabled_tap_to_learn_more")
        dcContext.setStockTranslation(id: DC_STR_NEW_GROUP_SEND_FIRST_MESSAGE, localizationKey: "chat_new_group_hint")
        dcContext.setStockTranslation(id: DC_STR_MESSAGE_ADD_MEMBER, localizationKey: "member_x_added")
        dcContext.setStockTranslation(id: DC_STR_INVALID_UNENCRYPTED_MAIL, localizationKey: "invalid_unencrypted_tap_to_learn_more")
        dcContext.setStockTranslation(id: DC_STR_YOU_REACTED, localizationKey: "reaction_by_you")
        dcContext.setStockTranslation(id: DC_STR_REACTED_BY, localizationKey: "reaction_by_other")
        dcContext.setStockTranslation(id: DC_STR_SECUREJOIN_WAIT, localizationKey: "secure_join_wait")
        dcContext.setStockTranslation(id: DC_STR_DONATION_REQUEST, localizationKey: "donate_device_msg")
        dcContext.setStockTranslation(id: DC_STR_OUTGOING_CALL, localizationKey: "outgoing_call")
        dcContext.setStockTranslation(id: DC_STR_INCOMING_CALL, localizationKey: "incoming_call")
        dcContext.setStockTranslation(id: DC_STR_DECLINED_CALL, localizationKey: "declined_call")
        dcContext.setStockTranslation(id: DC_STR_CANCELED_CALL, localizationKey: "canceled_call")
        dcContext.setStockTranslation(id: DC_STR_MISSED_CALL, localizationKey: "missed_call")
    }

    func appIsInForeground() -> Bool {
        if Thread.isMainThread {
            switch UIApplication.shared.applicationState {
            case .background, .inactive:
                applicationInForeground = false
            case .active:
                applicationInForeground = true
            @unknown default:
                applicationInForeground = false
            }
        }
        return applicationInForeground
    }
}

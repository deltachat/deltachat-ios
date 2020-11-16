import AudioToolbox
import Reachability
import SwiftyBeaver
import UIKit
import UserNotifications
import DcCore
import DBDebugToolkit

let logger = SwiftyBeaver.self

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private let dcContext = DcContext.shared
    var appCoordinator: AppCoordinator!
    var relayHelper: RelayHelper!
    var locationManager: LocationManager!
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    var reachability = Reachability()!
    var window: UIWindow?
    var appIsInForeground = false

    var incomingMsgObserver: Any?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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
        startThreads()
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
            print("Unable to start notifier")
        }

        if dcContext.isConfigured() {
            registerForPushNotifications()
        }

        return true
    }

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


    func application(_: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logger.info("---- background-fetch ----")
        startThreads()

        // we have 30 seconds time for our job, leave some seconds for graceful termination.
        // also, the faster we return, the sooner we get called again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if !self.appIsInForeground {
                self.dcContext.stopIo()
            }
            completionHandler(.newData)
        }
    }

    func applicationWillEnterForeground(_: UIApplication) {
        logger.info("---- foreground ----")
        appIsInForeground = true
        startThreads()
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
                self.stopThreads()
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

    func startThreads() {
        logger.info("---- start ----")
        dcContext.maybeStartIo()
    }

    func stopThreads() {
        dcContext.stopIo()
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
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // This function will be called right after user tap on the notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == Constants.notificationIdentifier {
            let userInfo = response.notification.request.content.userInfo
            logger.info("notifications: \(userInfo)")
            if let chatId = userInfo["chat_id"] as? Int,
               let msgId = userInfo["message_id"] as? Int {
                appCoordinator.showChat(chatId: chatId, msgId: msgId)
            }
        }

        completionHandler()
    }

    func userNotificationCenter(_: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        //remove foreground notifications after 3 seconds
        if notification.request.identifier == Constants.notificationIdentifier {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
            }
        }
        completionHandler([.alert, .sound])
    }

    func registerForPushNotifications() {
        logger.info("notifications: reister for push notifications")
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                logger.info("notifications: permission granted: \(granted)")
                guard granted else { return }
                self.getNotificationSettings()
            }

        let nc = NotificationCenter.default
        incomingMsgObserver = nc.addObserver(
            forName: dcNotificationIncoming,
            object: nil, queue: OperationQueue.main
        ) { [weak self] notification in
            guard let self = self else { return }
            let array = DcContext.shared.getFreshMessages()
            UIApplication.shared.applicationIconBadgeNumber = array.count

            let lastActiveChat = AppStateRestorer.shared.restoreLastActiveChatId()
            if let ui = notification.userInfo,
               let chatId = ui["chat_id"] as? Int,
               lastActiveChat != chatId,
               let msgId = ui["message_id"] as? Int {
                let chat = self.dcContext.getChat(chatId: chatId)
                if !UserDefaults.standard.bool(forKey: "notifications_disabled") && !chat.isMuted {
                    let content = UNMutableNotificationContent()
                    let msg = DcMsg(id: msgId)
                    content.title = chat.isGroup ? chat.name : msg.fromContact.displayName
                    content.body =  msg.summary(chars: 80) ?? ""
                    content.subtitle = chat.isGroup ?  msg.fromContact.displayName : ""
                    content.userInfo = ui
                    content.sound = .default

                    /*if let url = msg.fileURL,
                       let attachment = try? UNNotificationAttachment(identifier: Constants.notificationIdentifier, url: url, options: nil) {
                        content.attachments = [attachment]
                    }*/

                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
                    let request = UNNotificationRequest(identifier: Constants.notificationIdentifier, content: content, trigger: trigger)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                    DcContext.shared.logger?.info("notifications: added \(content)")
                }

            }

        }
    }

    private func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            logger.info("notifications: Notification settings: \(settings)")
        }
    }
}

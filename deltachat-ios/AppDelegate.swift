//
//  AppDelegate.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 06.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import AudioToolbox
import DBDebugToolkit
import Reachability
import SwiftyBeaver
import UIKit
import UserNotifications

var mailboxPointer: UnsafeMutablePointer<dc_context_t>!
let logger = SwiftyBeaver.self

enum ApplicationState {
    case stopped
    case running
    case background
    case backgroundFetch
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let appCoordinator = AppCoordinator()
    static var progress: Float = 0
    static var lastErrorDuringConfig: String?
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    var reachability = Reachability()!
    var window: UIWindow?

    var state = ApplicationState.stopped

    private func getCoreInfo() -> [[String]] {
        if let cInfo = dc_get_info(mailboxPointer) {
            let info = String(cString: cInfo)
            logger.info(info)
            return info.components(separatedBy: "\n").map { val in
                val.components(separatedBy: "=")
            }
        }

        return []
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
        AppDelegate.appCoordinator.setupViewControllers(window: window)

        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

        start()
        open()

        registerForPushNotifications()

        return true
    }

    func application(_: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logger.info("---- background-fetch ----")

        if mailboxPointer == nil {
            //       - second param remains nil (user data for more than one mailbox)
            mailboxPointer = dc_context_new(callback_ios, nil, "iOS")
            guard mailboxPointer != nil else {
                fatalError("Error: dc_context_new returned nil")
            }
        }

        if state == .background {
            state = .backgroundFetch

            dc_perform_imap_fetch(mailboxPointer)
            dc_perform_mvbox_fetch(mailboxPointer)

            // TODO: actually set the right value depending on if we found sth
            completionHandler(.newData)

            state = .background
        } else {
            // only start a round of jobs if we are not already doing one
            completionHandler(.noData)
        }
    }

    func applicationWillEnterForeground(_: UIApplication) {
        logger.info("---- foreground ----")
        start()
    }

    func applicationDidEnterBackground(_: UIApplication) {
        logger.info("---- background ----")

        // stop()
        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)
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

        _ = dc_open(mailboxPointer, dbfile(), nil)
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

    func start() {
        logger.info("---- start ----")

        if state == .running {
            return
        }

        if mailboxPointer == nil {
            //       - second param remains nil (user data for more than one mailbox)
            mailboxPointer = dc_context_new(callback_ios, nil, "iOS")
            guard mailboxPointer != nil else {
                fatalError("Error: dc_context_new returned nil")
            }
        }

        state = .running

        DispatchQueue.global(qos: .background).async {
            self.registerBackgroundTask()
            while self.state == .running {
                DispatchQueue.main.async {
                    switch UIApplication.shared.applicationState {
                    case .active:
                        logger.info("active - imap")
                    case .background:
                        logger.info("background - time remaining = " +
                            "\(UIApplication.shared.backgroundTimeRemaining) seconds")
                    case .inactive:
                        break
                    }
                }

                dc_perform_imap_jobs(mailboxPointer)
                dc_perform_imap_fetch(mailboxPointer)
                dc_perform_imap_idle(mailboxPointer)
            }
            if self.backgroundTask != .invalid {
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

        if MRConfig.sentboxWatch {
            DispatchQueue.global(qos: .background).async {
                while self.state == .running {
                    dc_perform_sentbox_fetch(mailboxPointer)
                    dc_perform_sentbox_idle(mailboxPointer)
                }
            }
        }

        if MRConfig.mvboxWatch {
            DispatchQueue.global(qos: .background).async {
                while self.state == .running {
                    dc_perform_mvbox_fetch(mailboxPointer)
                    dc_perform_mvbox_idle(mailboxPointer)
                }
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilityChanged, object: reachability)
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

    @objc func reachabilityChanged(note: Notification) {
        let reachability = note.object as! Reachability

        switch reachability.connection {
        case .wifi, .cellular:
            logger.info("network: reachable", reachability.connection.description)
            dc_maybe_network(mailboxPointer)

            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                nc.post(name: dc_notificationStateChanged,
                        object: nil,
                        userInfo: ["state": "online"])
            }
        case .none:
            logger.info("network: not reachable")
            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                nc.post(name: dc_notificationStateChanged,
                        object: nil,
                        userInfo: ["state": "offline"])
            }
        }
    }

    // MARK: - BackgroundTask

    func registerBackgroundTask() {
        logger.info("background task registered")
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        assert(backgroundTask != .invalid)
    }

    func endBackgroundTask() {
        logger.info("background task ended")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    // MARK: - PushNotifications

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) {
                granted, _ in
                logger.info("permission granted: \(granted)")
                guard granted else { return }
                self.getNotificationSettings()
            }
    }

    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            logger.info("Notification settings: \(settings)")
        }
    }

    func userNotificationCenter(_: UNUserNotificationCenter, willPresent _: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        logger.info("forground notification")
        completionHandler([.alert, .sound])
    }

    func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == Constants.notificationIdentifier {
            logger.info("handling notifications")
            let userInfo = response.notification.request.content.userInfo
            let nc = NotificationCenter.default
            DispatchQueue.main.async {
                nc.post(
                    name: dc_notificationViewChat,
                    object: nil,
                    userInfo: userInfo
                )
            }
        }

        completionHandler()
    }
}

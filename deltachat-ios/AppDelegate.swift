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
class AppDelegate: UIResponder, UIApplicationDelegate {
    static let appCoordinator = AppCoordinator()
    static var progress: Float = 0
    static var lastErrorDuringConfig: String?
    static var cancellableCredentialsController = false

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

        let ud = UserDefaults.standard
        if ud.bool(forKey: Constants.Keys.deltachatUserProvidedCredentialsKey) {
            initCore(withCredentials: false)
        }

        // registerForPushNotifications()

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

        stop()

        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)
    }

    func applicationWillTerminate(_: UIApplication) {
        logger.info("---- terminate ----")
        close()
    }

    private func open() {
        let paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        let documentsPath = paths[0]
        let dbfile = documentsPath + "/messenger.db"
        logger.info("open: \(dbfile)")

        _ = dc_open(mailboxPointer, dbfile, nil)
    }

    func stop() {
        state = .background

        dc_interrupt_imap_idle(mailboxPointer)
        dc_interrupt_smtp_idle(mailboxPointer)
        dc_interrupt_mvbox_idle(mailboxPointer)
        dc_interrupt_sentbox_idle(mailboxPointer)
    }

    private func close() {
        state = .stopped

        dc_close(mailboxPointer)
        mailboxPointer = nil

        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)
    }

    func start() {
        logger.info("---- start ----")

        if mailboxPointer == nil {
            //       - second param remains nil (user data for more than one mailbox)
            mailboxPointer = dc_context_new(callback_ios, nil, "iOS")
            guard mailboxPointer != nil else {
                fatalError("Error: dc_context_new returned nil")
            }
        }

        state = .running

        DispatchQueue.global(qos: .background).async {
            while self.state == .running {
                dc_perform_imap_jobs(mailboxPointer)
                dc_perform_imap_fetch(mailboxPointer)
                dc_perform_imap_idle(mailboxPointer)
            }
        }

        DispatchQueue.global(qos: .utility).async {
            while self.state == .running {
                dc_perform_smtp_jobs(mailboxPointer)
                dc_perform_smtp_idle(mailboxPointer)
            }
        }

        DispatchQueue.global(qos: .background).async {
            while self.state == .running {
                dc_perform_sentbox_fetch(mailboxPointer)
                dc_perform_sentbox_idle(mailboxPointer)
            }
        }

        DispatchQueue.global(qos: .background).async {
            while self.state == .running {
                dc_perform_mvbox_fetch(mailboxPointer)
                dc_perform_mvbox_idle(mailboxPointer)
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

    func registerForPushNotifications() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) {
                granted, _ in
                logger.info("permission granted: \(granted)")
            }
    }
}

func initCore(withCredentials: Bool, advancedMode: Bool = false, model: CredentialsModel? = nil, cancellableCredentialsUponFailure: Bool = false) {
    AppDelegate.cancellableCredentialsController = cancellableCredentialsUponFailure

    if withCredentials {
        guard let model = model else {
            fatalError("withCredentials == true implies non-nil model")
        }
        if !(model.email.contains("@") && (model.email.count >= 3)) {
            fatalError("initCore called with withCredentials flag set to true, but email not valid")
        }
        if model.password.isEmpty {
            fatalError("initCore called with withCredentials flag set to true, password is empty")
        }
        dc_set_config(mailboxPointer, "addr", model.email)
        dc_set_config(mailboxPointer, "mail_pw", model.password)
        if advancedMode {
            if let imapLoginName = model.imapLoginName {
                dc_set_config(mailboxPointer, "mail_user", imapLoginName)
            }
            if let imapServer = model.imapServer {
                dc_set_config(mailboxPointer, "mail_server", imapServer)
            }
            if let imapPort = model.imapPort {
                dc_set_config(mailboxPointer, "mail_port", imapPort)
            }

            if let smtpLoginName = model.smtpLoginName {
                dc_set_config(mailboxPointer, "send_user", smtpLoginName)
            }
            if let smtpPassword = model.smtpPassword {
                dc_set_config(mailboxPointer, "send_pw", smtpPassword)
            }
            if let smtpServer = model.smtpServer {
                dc_set_config(mailboxPointer, "send_server", smtpServer)
            }
            if let smtpPort = model.smtpPort {
                dc_set_config(mailboxPointer, "send_port", smtpPort)
            }

            var flags: Int32 = 0
            if model.smtpSecurity == .automatic, (model.imapSecurity == .automatic) {
                flags = DC_LP_AUTH_NORMAL
            } else {
                if model.smtpSecurity == .off {
                    flags |= DC_LP_SMTP_SOCKET_PLAIN
                } else if model.smtpSecurity == .ssltls {
                    flags |= DC_LP_SMTP_SOCKET_SSL
                } else if model.smtpSecurity == .starttls {
                    flags |= DC_LP_SMTP_SOCKET_STARTTLS
                }

                if model.imapSecurity == .off {
                    flags |= DC_LP_IMAP_SOCKET_PLAIN
                } else if model.imapSecurity == .ssltls {
                    flags |= DC_LP_IMAP_SOCKET_SSL
                } else if model.imapSecurity == .starttls {
                    flags |= DC_LP_IMAP_SOCKET_STARTTLS
                }
            }
            let ptr: UnsafeMutablePointer<Int32> = UnsafeMutablePointer.allocate(capacity: 1)
            ptr.pointee = flags
            let rp = UnsafeRawPointer(ptr)
            // rebind memory from Int32 to Int8
            let up = rp.bindMemory(to: Int8.self, capacity: 1)
            dc_set_config(mailboxPointer, "server_flags", up)
        }

        // TODO: - handle failure, need to show credentials screen again
        dc_configure(mailboxPointer)
        // TODO: next two lines should move here in success case
        // UserDefaults.standard.set(true, forKey: Constants.Keys.deltachatUserProvidedCredentialsKey)
        // UserDefaults.standard.synchronize()
    }

    addVibrationOnIncomingMessage()
}

func addVibrationOnIncomingMessage() {
    let nc = NotificationCenter.default
    nc.addObserver(forName: Notification.Name(rawValue: "MrEventIncomingMsg"),
                   object: nil, queue: nil) {
        _ in
        AudioServicesPlaySystemSound(UInt32(kSystemSoundID_Vibrate))
    }
}

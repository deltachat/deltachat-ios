//
//  AppDelegate.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 06.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit
import AudioToolbox


var mailboxPointer:UnsafeMutablePointer<dc_context_t>!

@_silgen_name("callbackSwift")

public func callbackSwift(event: CInt, data1: CUnsignedLong, data2: CUnsignedLong, data1String: UnsafePointer<Int8>, data2String: UnsafePointer<Int8>) -> UnsafePointer<Int8>? {
    
    switch event {
    case DC_EVENT_HTTP_GET:
        let urlString = String(cString: data1String)
        guard let url = URL(string: urlString) else {
            return nil
        }
        guard let configText = try? String(contentsOf: url) else {
            return nil
        }
        // see the strdup tip here: https://oleb.net/blog/2016/10/swift-array-of-c-strings/#alternative-strdup-and-free
        let p = UnsafePointer(strdup(configText))
        return p
    case DC_EVENT_INFO:
        let s = String(cString: data2String)
        print("Info: \(s)")
    case DC_EVENT_WARNING:
        let s = String(cString: data2String)
        print("Warning: \(s)")
    case DC_EVENT_ERROR:
        let s = String(cString: data2String)
        print("Error: \(s)")
    // TODO
    // check online state, return
    // - 0 when online
    // - 1 when offline
    case DC_EVENT_CONFIGURE_PROGRESS:
        DispatchQueue.main.async {
            // progress in promille, 0 - error, 1000 - completed
            let progressInPromille = Float(data1)
            AppDelegate.progress = progressInPromille / 1000
            print("progress: \(AppDelegate.progress)")
            if data1 == 1000 {
                AppDelegate.appCoordinator.setupInnerViewControllers()
            }
            if data1 == 0 {
                AppDelegate.appCoordinator.displayCredentialsController()
            }
            let nc = NotificationCenter.default
            
            DispatchQueue.main.async {
                nc.post(name:Notification.Name(rawValue:"ProgressUpdated"),
                        object: nil,
                        userInfo: ["message":"Progress updated", "date":Date()])
            }
        }
        return nil
    case DC_EVENT_IS_OFFLINE:
        return nil
    case DC_EVENT_MSGS_CHANGED:
        // TODO: reload all views
        // e.g. when message appears that is not new, i.e. no need
        // to set badge / notification
        
        let nc = NotificationCenter.default
        
        DispatchQueue.main.async {
            nc.post(name:Notification.Name(rawValue:"MrEventMsgsChanged"),
                    object: nil,
                    userInfo: ["message":"Messages Changed!", "date":Date()])
        }

    case DC_EVENT_INCOMING_MSG:
        // TODO: reload all views + set notification / badge
        // mrmailbox_get_fresh_msgs
        let nc = NotificationCenter.default
        DispatchQueue.main.async {
            nc.post(name:Notification.Name(rawValue:"MrEventIncomingMsg"),
                    object: nil,
                    userInfo: ["message":"Incoming Message!", "date":Date()])
        }
    default:
        break
    }
    return nil
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    static let appCoordinator = AppCoordinator()
    static var progress:Float = 0
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        window = UIWindow(frame: UIScreen.main.bounds)
        guard let window = window else {
            fatalError("window was nil in app delegate")
        }
        AppDelegate.appCoordinator.setupViewControllers(window: window)

        return true
    }
}


func initCore(withCredentials: Bool, email: String = "", password: String = "") {
    let paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
    let documentsPath = paths[0]
    let dbfile = documentsPath + "/messenger.db"
    print(dbfile)
    
    //       - second param remains nil (user data for more than one mailbox)
    mailboxPointer = dc_context_new(callback_ios, nil, "iOS")
    guard mailboxPointer != nil else {
        fatalError("Error: dc_context_new returned nil")
    }
    
    DispatchQueue.global().async {
        while true {
            dc_perform_imap_jobs(mailboxPointer)
            dc_perform_imap_fetch(mailboxPointer)
            dc_perform_imap_idle(mailboxPointer)
        }
    }
    
    DispatchQueue.global().async {
        while true {
            dc_perform_smtp_jobs(mailboxPointer)
            dc_perform_smtp_idle(mailboxPointer)
        }
    }
    
    let _ = dc_open(mailboxPointer, dbfile, nil)
    
    if withCredentials {
        if !(email.contains("@") && (email.count >= 3)) {
            fatalError("initCore called with withCredentials flag set to true, but email not valid")
        }
        if password.isEmpty {
            fatalError("initCore called with withCredentials flag set to true, password is empty")
        }
        dc_set_config(mailboxPointer, "addr", email)
        dc_set_config(mailboxPointer, "mail_pw", password)

        UserDefaults.standard.set(true, forKey: Constants.Keys.deltachatUserProvidedCredentialsKey)
        UserDefaults.standard.synchronize()
        
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
    nc.addObserver(forName:Notification.Name(rawValue:"MrEventIncomingMsg"),
                   object:nil, queue:nil) {
                    notification in
                    print("----------- MrEventIncomingMsg received --------")
                    AudioServicesPlaySystemSound(UInt32(kSystemSoundID_Vibrate))
    }
}

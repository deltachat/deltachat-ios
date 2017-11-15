//
//  AppDelegate.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 06.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit
import AudioToolbox


var mailboxPointer:UnsafeMutablePointer<mrmailbox_t>!

func sendTestMessage(name n: String, email: String, text: String) {
    let contactId = mrmailbox_create_contact(mailboxPointer, n, email)
    let chatId = mrmailbox_create_chat_by_contact_id(mailboxPointer, contactId)
//    mrmailbox_send_text_msg(mailboxPointer, chatId, text)
}

@_silgen_name("callbackSwift")

public func callbackSwift(event: CInt, data1: CUnsignedLong, data2: CUnsignedLong, data1String: UnsafePointer<Int8>, data2String: UnsafePointer<Int8>) -> CUnsignedLong {
    
    switch event {
    case MR_EVENT_INFO:
        let s = String(cString: data2String)
        print("Info: \(s)")
    case MR_EVENT_WARNING:
        let s = String(cString: data2String)
        print("Warning: \(s)")
    case MR_EVENT_ERROR:
        let s = String(cString: data2String)
        print("Error: \(s)")
    // TODO
    // check online state, return
    // - 0 when online
    // - 1 when offline
    case MR_EVENT_IS_OFFLINE:
        return 0
    // TODO
    // this will become a synchronous API, start thread directly
    // from
    case MR_EVENT_CONFIGURE_ENDED:
        if data1 == 0 {
            fatalError("MR_EVENT_CONFIGURE_ENDED: (TODO: add dialogue here)")
        } else {
//            sendTestMessage(name: "Q", email: "quickmsgtest1@b44t.com", text: "hugu")
        }
        
        break
//        mrmailbox_send
    case MR_EVENT_MSGS_CHANGED:
        // TODO: reload all views
        // e.g. when message appears that is not new, i.e. no need
        // to set badge / notification
        
        let nc = NotificationCenter.default
        
        DispatchQueue.main.async {
            nc.post(name:Notification.Name(rawValue:"MrEventMsgsChanged"),
                    object: nil,
                    userInfo: ["message":"Messages Changed!", "date":Date()])
        }

    case MR_EVENT_INCOMING_MSG:
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
    return 0
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    static let appCoordinator = AppCoordinator()
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
    mailboxPointer = mrmailbox_new(callback_ios, nil, "iOS")
    guard mailboxPointer != nil else {
        fatalError("Error: mrmailbox_new returned nil")
    }
    
    let _ = mrmailbox_open(mailboxPointer, dbfile, nil)
    
    if withCredentials {
        if !(email.contains("@") && (email.count >= 3)) {
            fatalError("initCore called with withCredentials flag set to true, but email not valid")
        }
        if password.isEmpty {
            fatalError("initCore called with withCredentials flag set to true, password is empty")
        }
        mrmailbox_set_config(mailboxPointer, "addr", email)
        mrmailbox_set_config(mailboxPointer, "mail_pw", password)
//            -        mrmailbox_set_config(mailboxPointer, "addr", "alice@librechat.net")
//            -        mrmailbox_set_config(mailboxPointer, "mail_pw", "foobar")
        UserDefaults.standard.set(true, forKey: Constants.Keys.deltachatUserProvidedCredentialsKey)
        UserDefaults.standard.synchronize()
    }
    
    mrmailbox_configure_and_connect(mailboxPointer)
    
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

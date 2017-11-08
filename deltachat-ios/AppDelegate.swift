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
    mrmailbox_send_text_msg(mailboxPointer, chatId, text)
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
    case MR_EVENT_IS_ONLINE:
        return 1
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

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        window = UIWindow(frame: UIScreen.main.bounds)
        guard let window = window else {
            fatalError("window was nil in app delegate")
        }
        let appCoordinator = AppCoordinator()
        appCoordinator.setupViewControllers(window: window)
        
    
        
        
        guard let ump = mrmailbox_get_version_str() else {
            fatalError("Error: invalid version string")
        }
        let versionString = String(cString: ump)
        print(versionString)

        //       - second param remains nil (user data for more than one mailbox)
        mailboxPointer = mrmailbox_new(callback_ios, nil, "iOS")
        guard mailboxPointer != nil else {
            fatalError("Error: mrmailbox_new returned nil")
        }
        let mailbox = mailboxPointer.pointee
        
        let paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        let documentsPath = paths[0]
        let dbfile = documentsPath + "/messenger.db"
        print(dbfile)
        
        let r = mrmailbox_open(mailboxPointer, dbfile, nil)
        
        mrmailbox_set_config(mailboxPointer, "addr", "alice@librechat.net")
        mrmailbox_set_config(mailboxPointer, "mail_pw", "foobar")
        
        mrmailbox_configure_and_connect(mailboxPointer)
        print(r)
        
        let nc = NotificationCenter.default
        nc.addObserver(forName:Notification.Name(rawValue:"MrEventMsgsChanged"),
                       object:nil, queue:nil) {
                        notification in
                        print("----------- MrEventMsgsChanged notification received --------")
        }
        
        nc.addObserver(forName:Notification.Name(rawValue:"MrEventIncomingMsg"),
                       object:nil, queue:nil) {
                        notification in
                        print("----------- MrEventIncomingMsg received --------")
                        AudioServicesPlaySystemSound(UInt32(kSystemSoundID_Vibrate))
        }


        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}


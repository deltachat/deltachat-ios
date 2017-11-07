//
//  AppDelegate.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 06.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

var mailboxPointer:UnsafeMutablePointer<mrmailbox_t>!

func sendMessageSwiftOnly(chatPointer: UnsafeMutablePointer<mrchat_t>, msgPointer: UnsafeMutablePointer<mrmsg_t>, msg: String) {
    msg.withCString {
        cString in
        let s:UnsafeMutablePointer<Int8> = UnsafeMutablePointer(mutating: cString)
        msgPointer.pointee.m_text = s
        msgPointer.pointee.m_type = MR_MSG_TEXT
        mrchat_send_msg(chatPointer, msgPointer)
    }
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
            let contactId = mrmailbox_create_contact(mailboxPointer, "Björn", "bpetersen@b44t.com")
            let chatId = mrmailbox_create_chat_by_contact_id(mailboxPointer, contactId)
            let chatPointer = mrmailbox_get_chat(mailboxPointer, chatId)
            let msgPointer = mrmsg_new()!

            sendMessageSwiftOnly(chatPointer: chatPointer!, msgPointer: msgPointer, msg: "uziuzi")
        }
        
        break
//        mrmailbox_send
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
        window.rootViewController = ViewController()
        window.makeKeyAndVisible()
        window.backgroundColor = UIColor.white
        
        guard let ump = mrmailbox_get_version_str() else {
            fatalError("Error: invalid version string")
        }
        let versionString = String(cString: ump)
        print(versionString)

        //       - second param remains nil (user data for more than one mailbox)
        mailboxPointer = mrmailbox_new(callback_ios, nil)
        guard mailboxPointer != nil else {
            fatalError("Error: mrmailbox_new returned nil")
        }
        let mailbox = mailboxPointer.pointee
        
        let paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        let documentsPath = paths[0]
        let dbfile = documentsPath + "/messenger.db"
        print(dbfile)
        
        let r = mrmailbox_open(mailboxPointer, dbfile, nil)
        mrmailbox_set_config(mailboxPointer, "addr", "bob@librechat.net")
        mrmailbox_set_config(mailboxPointer, "mail_pw", "foobar")
        mrmailbox_configure_and_connect(mailboxPointer)
        print(r)

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


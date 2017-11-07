//
//  AppDelegate.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 06.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit


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
    default:
        break
    }
    return 0
}

extension String {
    var nullTerminated: Data? {
        if var data = self.data(using: String.Encoding.utf8) {
            data.append(0)
            return data
        }
        return nil
    }
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
        
        // TODO: - add callback as first parameter
        //       - second param remains nil (user data for more than one mailbox)
        

        guard let m = mrmailbox_new(callback_ios, nil) else {
            fatalError("Error: mrmailbox_new returned nil")
        }
        let mailbox = m.pointee
        
        let paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        let documentsPath = paths[0]
        let dbfile = documentsPath + "/messenger.db"
        print(dbfile)
        
//        let nt:Data? = dbfile.nullTerminated

        let r = mrmailbox_open(m, dbfile, nil)
        print(r)
        
//        mrmailbox_c

//        dbfile.withCString {
//            (cString:UnsafePointer<Int8>) in
//            mrmailbox_open(m, cString, nil)
//        }
        
        //
        
        //        guard let dbfileCString = dbfile.cString(using: .utf8) else {
//            fatalError("Error: error converting to cstring")
//        }

//        mrmailbox_open(m, nt, nil)

//        let msql = mailbox.m_sql
//        print(msql)

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


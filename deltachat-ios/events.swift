//
//  events.swift
//  deltachat-ios
//
//  Created by Friedel Ziegelmayer on 27.12.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UserNotifications

let dc_notificationChanged = Notification.Name(rawValue: "MrEventMsgsChanged")
let dc_notificationStateChanged = Notification.Name(rawValue: "MrEventStateChanged")
let dc_notificationIncoming = Notification.Name(rawValue: "MrEventIncomingMsg")
let dc_notificationBackupProgress = Notification.Name(rawValue: "MrEventBackupProgress")
let dc_notificationConfigureProgress = Notification.Name(rawValue: "MrEventConfigureProgress")

@_silgen_name("callbackSwift")

public func callbackSwift(event: CInt, data1: CUnsignedLong, data2: CUnsignedLong, data1String: UnsafePointer<Int8>, data2String: UnsafePointer<Int8>) -> UnsafePointer<Int8>? {
    switch event {
    case DC_EVENT_HTTP_GET:
        let urlString = String(cString: data1String)
        logger.info("network: http get: \(urlString)")
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
        logger.info("event: \(s)")
    case DC_EVENT_WARNING:
        let s = String(cString: data2String)
        logger.warning("event: \(s)")
    case DC_EVENT_ERROR:
        let s = String(cString: data2String)
        AppDelegate.lastErrorDuringConfig = s
        logger.error("event: \(s)")
    // TODO:
    // check online state, return
    // - 0 when online
    // - 1 when offline
    case DC_EVENT_CONFIGURE_PROGRESS:
        logger.info("configure progress: \(Int(data1)) \(Int(data2))")
        let nc = NotificationCenter.default
        DispatchQueue.main.async {
            let done = Int(data1) == 1000

            nc.post(
                name: dc_notificationConfigureProgress,
                object: nil,
                userInfo: [
                    "progress": Int(data1),
                    "error": Int(data1) == 0,
                    "done": done,
                    "errorMessage": AppDelegate.lastErrorDuringConfig,
                ]
            )

            if done {
                UserDefaults.standard.set(true, forKey: Constants.Keys.deltachatUserProvidedCredentialsKey)
                UserDefaults.standard.synchronize()
                AppDelegate.appCoordinator.setupInnerViewControllers()
                AppDelegate.lastErrorDuringConfig = nil
            }
        }
    case DC_EVENT_ERROR_NETWORK:
        let msg = String(cString: data2String)
        if data1 == 1 {
            AppDelegate.lastErrorDuringConfig = msg
            logger.error("network: \(msg)")
        } else {
            logger.warning("network: \(msg)")
        }

        let nc = NotificationCenter.default
        DispatchQueue.main.async {
            nc.post(name: dc_notificationStateChanged,
                    object: nil,
                    userInfo: ["state": "offline"])
        }
    case DC_EVENT_IMAP_CONNECTED, DC_EVENT_SMTP_CONNECTED:
        logger.warning("network: \(String(cString: data2String))")

        let nc = NotificationCenter.default
        DispatchQueue.main.async {
            nc.post(name: dc_notificationStateChanged,
                    object: nil,
                    userInfo: ["state": "online"])
        }
    case DC_EVENT_MSGS_CHANGED, DC_EVENT_MSG_READ, DC_EVENT_MSG_DELIVERED:
        // TODO: reload all views
        // e.g. when message appears that is not new, i.e. no need
        // to set badge / notification
        logger.info("change: \(event)")

        let nc = NotificationCenter.default

        DispatchQueue.main.async {
            nc.post(name: dc_notificationChanged,
                    object: nil,
                    userInfo: [
                        "message_id": Int(data2),
                        "chat_id": Int(data1),
                        "date": Date(),
            ])
        }
    case DC_EVENT_INCOMING_MSG:
        let nc = NotificationCenter.default

        DispatchQueue.main.async {
            nc.post(name: dc_notificationIncoming,
                    object: nil,
                    userInfo: [
                        "message_id": Int(data2),
                        "chat_id": Int(data1),
                        "date": Date(),
            ])
        }
    case DC_EVENT_SMTP_MESSAGE_SENT:
        logger.info("network: \(String(cString: data2String))")
    case DC_EVENT_MSG_DELIVERED:
        logger.info("message delivered: \(data1)-\(data2)")
    case DC_EVENT_IMEX_PROGRESS:
        let nc = NotificationCenter.default
        DispatchQueue.main.async {
            nc.post(
                name: dc_notificationBackupProgress,
                object: nil,
                userInfo: [
                    "progress": Int(data1),
                    "error": Int(data1) == 0,
                    "done": Int(data1) == 1000,
                    "errorMessage": AppDelegate.lastErrorDuringConfig,
                ]
            )
        }
    case DC_EVENT_IMEX_FILE_WRITTEN:
        logger.info("backup file written: \(String(cString: data1String))")
    case DC_EVENT_GET_STRING:
        // nothing to do for now
        break
    default:
        logger.warning("unknown event: \(event)")
    }

    return nil
}

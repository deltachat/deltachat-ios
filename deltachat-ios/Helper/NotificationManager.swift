import Foundation
import UserNotifications
import DcCore
import UIKit

public class NotificationManager {
    
    var incomingMsgObserver: NSObjectProtocol?
    var msgsNoticedObserver: NSObjectProtocol?

    init() {
        initIncomingMsgsObserver()
        initMsgsNoticedObserver()
    }

    public static func updateApplicationIconBadge(reset: Bool) {
        var unreadMessages = 0
        if !reset {
            unreadMessages = DcContext.shared.getFreshMessages().count
        }

        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = unreadMessages
        }
    }

    public static func removeAllNotifications() {
        let nc = UNUserNotificationCenter.current()
        nc.removeAllDeliveredNotifications()
        nc.removeAllPendingNotificationRequests()
    }
    
    public static func removeNotificationsForChat(chatId: Int) {
        DispatchQueue.global(qos: .background).async {
            NotificationManager.removePendingNotificationsFor(chatId: chatId)
            NotificationManager.removeDeliveredNotificationsFor(chatId: chatId)
            NotificationManager.updateApplicationIconBadge(reset: false)
        }
    }

    private func initIncomingMsgsObserver() {
        incomingMsgObserver = NotificationCenter.default.addObserver(
            forName: dcNotificationIncoming,
            object: nil, queue: OperationQueue.main
        ) { notification in
            DispatchQueue.global(qos: .background).async {
                if let ui = notification.userInfo,
                   let chatId = ui["chat_id"] as? Int,
                   let messageId = ui["message_id"] as? Int,
                   !UserDefaults.standard.bool(forKey: "notifications_disabled") {

                    NotificationManager.updateApplicationIconBadge(reset: false)

                    let chat = DcContext.shared.getChat(chatId: chatId)
                    if chat.isMuted {
                        return
                    }

                    let content = UNMutableNotificationContent()
                    let msg = DcMsg(id: messageId)
                    content.title = chat.isGroup ? chat.name : msg.getSenderName(msg.fromContact)
                    content.body =  msg.summary(chars: 80) ?? ""
                    content.subtitle = chat.isGroup ?  msg.getSenderName(msg.fromContact) : ""
                    content.userInfo = ui
                    content.sound = .default

                    if msg.type == DC_MSG_IMAGE || msg.type == DC_MSG_GIF,
                       let url = msg.fileURL {
                        do {
                            // make a copy of the file first since UNNotificationAttachment will move attached files into the attachment data store
                            // so that they can be accessed by all of the appropriate processes
                            let tempUrl = url.deletingLastPathComponent()
                                .appendingPathComponent("notification_tmp")
                                .appendingPathExtension(url.pathExtension)
                            try FileManager.default.copyItem(at: url, to: tempUrl)
                            if let attachment = try? UNNotificationAttachment(identifier: Constants.notificationIdentifier, url: tempUrl, options: nil) {
                                content.attachments = [attachment]
                            }
                        } catch let error {
                            logger.error("Failed to copy file \(url) for notification preview generation: \(error)")
                        }
                    }
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                    let accountEmail = DcContact(id: Int(DC_CONTACT_ID_SELF)).email
                    if #available(iOS 12.0, *) {
                        content.threadIdentifier = "\(accountEmail)\(chatId)"
                    }
                    let request = UNNotificationRequest(identifier: "\(Constants.notificationIdentifier).\(accountEmail).\(chatId).\(msg.messageId)",
                                                        content: content,
                                                        trigger: trigger)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                    logger.info("notifications: added \(content.title) \(content.body) \(content.userInfo)")
                }
            }
        }
    }

    private func initMsgsNoticedObserver() {
        msgsNoticedObserver =  NotificationCenter.default.addObserver(
            forName: dcMsgsNoticed,
            object: nil, queue: OperationQueue.main
        ) { notification in
            DispatchQueue.global(qos: .background).async {
                if !UserDefaults.standard.bool(forKey: "notifications_disabled") {
                    NotificationManager.updateApplicationIconBadge(reset: false)
                    if let ui = notification.userInfo,
                       let chatId = ui["chat_id"] as? Int {
                        NotificationManager.removePendingNotificationsFor(chatId: chatId)
                        NotificationManager.removeDeliveredNotificationsFor(chatId: chatId)
                    }
                }
            }
        }
    }

    private static func removeDeliveredNotificationsFor(chatId: Int) {
        var identifiers = [String]()
        let nc = UNUserNotificationCenter.current()
        nc.getDeliveredNotifications { notifications in
            let accountEmail = DcContact(id: Int(DC_CONTACT_ID_SELF)).email
            for notification in notifications {
                if !notification.request.identifier.containsExact(subSequence: "\(Constants.notificationIdentifier).\(accountEmail).\(chatId)").isEmpty {
                    identifiers.append(notification.request.identifier)
                }
            }
            nc.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    private static func removePendingNotificationsFor(chatId: Int) {
        var identifiers = [String]()
        let nc = UNUserNotificationCenter.current()
        nc.getPendingNotificationRequests { notificationRequests in
            let accountEmail = DcContact(id: Int(DC_CONTACT_ID_SELF)).email
            for request in notificationRequests {
                if !request.identifier.containsExact(subSequence: "\(Constants.notificationIdentifier).\(accountEmail).\(chatId)").isEmpty {
                    identifiers.append(request.identifier)
                }
            }
            nc.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}

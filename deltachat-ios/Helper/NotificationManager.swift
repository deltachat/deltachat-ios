import Foundation
import UserNotifications
import DcCore
import UIKit

public class NotificationManager {
    
    var anyIncomingMsgObserver: NSObjectProtocol?
    var incomingMsgObserver: NSObjectProtocol?
    var msgsNoticedObserver: NSObjectProtocol?

    private let dcAccounts: DcAccounts
    private var dcContext: DcContext

    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()
        initObservers()
    }

    public func reloadDcContext() {
        NotificationManager.removeAllNotifications()
        dcContext = dcAccounts.getSelected()
    }

    public static func updateApplicationIconBadge(forceZero: Bool = false) {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = forceZero ? 0 : DcAccounts.shared.getFreshMessageCount()
        }
    }

    public static func notificationEnabledInSystem(completionHandler: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            return completionHandler(settings.authorizationStatus != .denied)
        }
    }

    public static func removeAllNotifications() {
        let nc = UNUserNotificationCenter.current()
        nc.removeAllDeliveredNotifications()
        nc.removeAllPendingNotificationRequests()
    }
    
    public static func removeNotificationsForChat(dcContext: DcContext, chatId: Int) {
        DispatchQueue.global().async {
            NotificationManager.removePendingNotificationsFor(dcContext: dcContext, chatId: chatId)
            NotificationManager.removeDeliveredNotificationsFor(dcContext: dcContext, chatId: chatId)
            NotificationManager.updateApplicationIconBadge()
        }
    }

    private func initObservers() {
        anyIncomingMsgObserver = NotificationCenter.default.addObserver(
            forName: eventIncomingMsgAnyAccount,
            object: nil, queue: OperationQueue.main
        ) { _ in
            if !UserDefaults.standard.bool(forKey: "notifications_disabled") {
                NotificationManager.updateApplicationIconBadge()
            }
        }

        incomingMsgObserver = NotificationCenter.default.addObserver(
            forName: eventIncomingMsg,
            object: nil, queue: OperationQueue.main
        ) { notification in
            // make sure to balance each call to `beginBackgroundTask` with `endBackgroundTask`
            let backgroundTask = UIApplication.shared.beginBackgroundTask {
                // we cannot easily stop the task,
                // however, this handler should not be called as adding the notification should not take 30 seconds.
                logger.info("notification background task will end soon")
            }

            DispatchQueue.global().async { [weak self] in
                guard let self else { return }
                if let ui = notification.userInfo,
                   let chatId = ui["chat_id"] as? Int,
                   let messageId = ui["message_id"] as? Int,
                   !UserDefaults.standard.bool(forKey: "notifications_disabled") {

                    let chat = self.dcContext.getChat(chatId: chatId)

                    if !chat.isMuted {
                        let msg = self.dcContext.getMessage(id: messageId)
                        let fromContact = self.dcContext.getContact(id: msg.fromContactId)
                        let accountEmail = self.dcContext.getContact(id: Int(DC_CONTACT_ID_SELF)).email
                        let sender = msg.getSenderName(fromContact)
                        let content = UNMutableNotificationContent()
                        content.title = chat.isGroup ? chat.name : sender
                        content.body = (chat.isGroup ? "\(sender): " : "") + (msg.summary(chars: 80) ?? "")
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

                // this line should always be reached
                // and balances the call to `beginBackgroundTask` above.
                UIApplication.shared.endBackgroundTask(backgroundTask)
            }
        }

        msgsNoticedObserver =  NotificationCenter.default.addObserver(
            forName: eventMsgsNoticed,
            object: nil, queue: OperationQueue.main
        ) { [weak self] notification in
            guard let self else { return }
            if !UserDefaults.standard.bool(forKey: "notifications_disabled"),
               let ui = notification.userInfo,
               let chatId = ui["chat_id"] as? Int {
                NotificationManager.removeNotificationsForChat(dcContext: self.dcContext, chatId: chatId)
            }
        }
    }

    private static func removeDeliveredNotificationsFor(dcContext: DcContext, chatId: Int) {
        var identifiers = [String]()
        let nc = UNUserNotificationCenter.current()
        nc.getDeliveredNotifications { notifications in
            let accountEmail = dcContext.getContact(id: Int(DC_CONTACT_ID_SELF)).email
            for notification in notifications {
                if !notification.request.identifier.containsExact(subSequence: "\(Constants.notificationIdentifier).\(accountEmail).\(chatId)").isEmpty {
                    identifiers.append(notification.request.identifier)
                }
            }
            nc.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    private static func removePendingNotificationsFor(dcContext: DcContext, chatId: Int) {
        var identifiers = [String]()
        let nc = UNUserNotificationCenter.current()
        nc.getPendingNotificationRequests { notificationRequests in
            let accountEmail = dcContext.getContact(id: Int(DC_CONTACT_ID_SELF)).email
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

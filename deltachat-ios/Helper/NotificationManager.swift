import Foundation
import UserNotifications
import DcCore
import UIKit

public class NotificationManager {
    
    var incomingMsgObserver: Any?

    public static func updateApplicationIconBadge(reset: Bool) {
        if reset {
            UIApplication.shared.applicationIconBadgeNumber = 0
        } else {
            let array = DcContext.shared.getFreshMessages()
            UIApplication.shared.applicationIconBadgeNumber = array.count
        }
    }

    init() {
        incomingMsgObserver = NotificationCenter.default.addObserver(
            forName: dcNotificationIncoming,
            object: nil, queue: OperationQueue.main
        ) { notification in
            if let ui = notification.userInfo,
               let chatId = ui["chat_id"] as? Int,
               let messageId = ui["message_id"] as? Int {
                let chat = DcContext.shared.getChat(chatId: chatId)
                if !UserDefaults.standard.bool(forKey: "notifications_disabled") && !chat.isMuted {
                    DispatchQueue.global(qos: .background).async {
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

                        let request = UNNotificationRequest(identifier: Constants.notificationIdentifier, content: content, trigger: trigger)
                        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                        DcContext.shared.logger?.info("notifications: added \(content.title) \(content.body) \(content.userInfo)")
                    }
                }

                let array = DcContext.shared.getFreshMessages()
                UIApplication.shared.applicationIconBadgeNumber = array.count
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}

import Foundation
import UserNotifications
import DcCore
import UIKit

public class NotificationManager {
    
    var incomingMsgObserver: Any?
    
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
                    let content = UNMutableNotificationContent()
                    let msg = DcMsg(id: messageId)
                    content.title = msg.getSenderName(msg.fromContact)
                    content.body = msg.summary(chars: 40) ?? ""
                    content.userInfo = ui
                    content.sound = .default

                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

                    let request = UNNotificationRequest(identifier: Constants.notificationIdentifier, content: content, trigger: trigger)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                    DcContext.shared.logger?.info("notifications: added \(content.title) \(content.body) \(content.userInfo)")
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

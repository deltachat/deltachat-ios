import Foundation
import UserNotifications
import DcCore
import UIKit

public class NotificationManager {

    private let dcAccounts: DcAccounts
    private var dcContext: DcContext

    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()
        
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationManager.handleIncomingMessageOnAnyAccount(_:)), name: Event.incomingMessageOnAnyAccount, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationManager.handleIncomingReaction(_:)), name: Event.incomingReaction, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationManager.handleIncomingWebxdcNotify(_:)), name: Event.incomingWebxdcNotify, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationManager.handleMessagesNoticed(_:)), name: Event.messagesNoticed, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func reloadDcContext() {
        dcContext = dcAccounts.getSelected()
    }

    public static func updateBadgeCounters(forceZero: Bool = false) {
        DispatchQueue.main.async {
            let number = forceZero ? 0 : DcAccounts.shared.getFreshMessageCount()

            // update badge counter on iOS homescreen
            UIApplication.shared.applicationIconBadgeNumber = number

            // update badge counter on our tabbar
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
               let appCoordinator = appDelegate.appCoordinator,
               let chatsNavigationController = appCoordinator.tabBarController.viewControllers?[appCoordinator.chatsTab] {
                chatsNavigationController.tabBarItem.badgeValue = number > 0 ? "\(number)" : nil
            }
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
    }

    public static func removeNotificationsForChat(dcContext: DcContext, chatId: Int) {
        DispatchQueue.global().async {
            let nc = UNUserNotificationCenter.current()
            nc.getDeliveredNotifications { notifications in
                var toRemove = [String]()
                for notification in notifications {
                    let notificationAccountId = notification.request.content.userInfo["account_id"] as? Int ?? 0
                    let notificationChatId = notification.request.content.userInfo["chat_id"] as? Int ?? 0
                    // unspecific notifications are always removed
                    if notificationChatId == 0 || (notificationChatId == chatId && notificationAccountId == dcContext.id) {
                        toRemove.append(notification.request.identifier)
                    }
                }
                nc.removeDeliveredNotifications(withIdentifiers: toRemove)
            }

            NotificationManager.updateBadgeCounters()
        }
    }

    // MARK: - Notifications

    @objc private func handleMessagesNoticed(_ notification: Notification) {
        guard let ui = notification.userInfo,
            let chatId = ui["chat_id"] as? Int else { return }

        NotificationManager.removeNotificationsForChat(dcContext: self.dcContext, chatId: chatId)
    }

    @objc private func handleIncomingMessageOnAnyAccount(_ notification: Notification) {
        NotificationManager.updateBadgeCounters()

        // make sure to balance each call to `beginBackgroundTask` with `endBackgroundTask`
        let backgroundTask = UIApplication.shared.beginBackgroundTask {
            // we cannot easily stop the task,
            // however, this handler should not be called as adding the notification should not take 30 seconds.
            logger.info("notification background task will end soon")
        }

        DispatchQueue.global().async { [weak self] in
            guard let self,
                  let accountId = notification.userInfo?["account_id"] as? Int,
                  let chatId = notification.userInfo?["chat_id"] as? Int,
                  let messageId = notification.userInfo?["message_id"] as? Int
            else { return }
            let eventContext = dcAccounts.get(id: accountId)
            let chat = eventContext.getChat(chatId: chatId)
            let msg = eventContext.getMessage(id: messageId)
            if let content = UNMutableNotificationContent(forMessage: msg, chat: chat, context: eventContext) {
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                logger.info("notification added for \(messageId)")
            }

            // this line should always be reached
            // and balances the call to `beginBackgroundTask` above.
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }
    }

    @objc private func handleIncomingReaction(_ notification: Notification) {
        let backgroundTask = UIApplication.shared.beginBackgroundTask {
            logger.info("incoming-reaction-task will end soon")
        }

        DispatchQueue.global().async { [weak self] in
            guard let self,
                  let accountId = notification.userInfo?["account_id"] as? Int,
                  let msgId = notification.userInfo?["msg_id"] as? Int,
                  let reaction = notification.userInfo?["reaction"] as? String,
                  let contact = notification.userInfo?["contact_id"] as? Int
            else { return }
            let eventContext = dcAccounts.get(id: accountId)
            let msg = eventContext.getMessage(id: msgId)
            let chat = eventContext.getChat(chatId: msg.chatId)
            if let content = UNMutableNotificationContent(forReaction: reaction, from: contact, msg: msg, chat: chat, context: eventContext) {
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }

            UIApplication.shared.endBackgroundTask(backgroundTask) // this line must be reached to balance call to `beginBackgroundTask` above
        }
    }

    @objc private func handleIncomingWebxdcNotify(_ notification: Notification) {
        let backgroundTask = UIApplication.shared.beginBackgroundTask {
            logger.info("incoming-webxdc-notify-task will end soon")
        }

        DispatchQueue.global().async { [weak self] in
            guard let self,
                  let accountId = notification.userInfo?["account_id"] as? Int,
                  let msgId = notification.userInfo?["msg_id"] as? Int,
                  let text = notification.userInfo?["text"] as? String
            else { return }
            let eventContext = dcAccounts.get(id: accountId)
            let msg = eventContext.getMessage(id: msgId)
            let chat = eventContext.getChat(chatId: msg.chatId)
            if let content = UNMutableNotificationContent(forWebxdcNotification: text, msg: msg, chat: chat, context: eventContext) {
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }

            UIApplication.shared.endBackgroundTask(backgroundTask) // this line must be reached to balance call to `beginBackgroundTask` above
        }
    }
}

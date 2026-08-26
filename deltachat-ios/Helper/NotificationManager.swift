import Foundation
import UserNotifications
import DcCore
import UIKit

public class NotificationManager {

    private let dcAccounts: DcAccounts
    private let inOneSecond = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    private static let unc = UNUserNotificationCenter.current()

    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationManager.handleIncomingMessageOnAnyAccount(_:)), name: Event.incomingMessageOnAnyAccount, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationManager.handleIncomingReaction(_:)), name: Event.incomingReaction, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationManager.handleIncomingWebxdcNotify(_:)), name: Event.incomingWebxdcNotify, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationManager.handleMessagesNoticed(_:)), name: Event.messagesNoticed, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public static func updateBadgeCounters(forceZero: Bool = false) {
        #if MAIN_APPLICATION
        DispatchQueue.main.async {
            let number = forceZero ? 0 : DcAccounts.shared.getFreshMessagesCount()

            // update badge counter on iOS homescreen
            UIApplication.shared.applicationIconBadgeNumber = number

            let appDelegate = UIApplication.shared.delegate as? AppDelegate

            // update badge counter on our tabbar
            if let appCoordinator = appDelegate?.appCoordinator,
               let chatsNavigationController = appCoordinator.tabBarController.viewControllers?[appCoordinator.chatsTab] {
                chatsNavigationController.tabBarItem.badgeValue = number > 0 ? "\(number)" : nil
            }

            appDelegate?.callWindow?.callViewController?.setUnreadMessageCount(number)
        }
        #endif
    }

    public static func notificationEnabledInSystem(completionHandler: @escaping (Bool) -> Void) {
        unc.getNotificationSettings { settings in
            completionHandler(settings.authorizationStatus != .denied)
        }
    }

    public static func removeAllNotifications() {
        unc.removeAllDeliveredNotifications()
    }

    public static func removeNotificationsForChat(_ chatId: Int, accountId: Int) {
        Task {
            let noticedThreadId = "\(accountId)-\(chatId)"
            let pendingNotificationIds = await unc.pendingNotificationRequests()
                .filter { $0.content.threadIdentifier == noticedThreadId }
                .map { $0.identifier }
            unc.removePendingNotificationRequests(withIdentifiers: pendingNotificationIds)
            let deliveredNotificationIds = await unc.deliveredNotifications()
                .filter { $0.request.content.threadIdentifier == noticedThreadId }
                .map { $0.request.identifier }
            unc.removeDeliveredNotifications(withIdentifiers: deliveredNotificationIds)

            NotificationManager.updateBadgeCounters()
        }
    }

    public static func removeNotificationsForAccount(accountId: Int) {
        Task {
            let pendingNotificationIds = await unc.pendingNotificationRequests()
                .filter { $0.content.userInfo["account_id"] as? Int == accountId }
                .map { $0.identifier }
            unc.removePendingNotificationRequests(withIdentifiers: pendingNotificationIds)
            let deliveredNotificationIds = await unc.deliveredNotifications()
                .filter { $0.request.content.userInfo["account_id"] as? Int == accountId }
                .map { $0.request.identifier }
            unc.removeDeliveredNotifications(withIdentifiers: deliveredNotificationIds)

            NotificationManager.updateBadgeCounters()
        }
    }

    // MARK: - Notifications

    @objc private func handleMessagesNoticed(_ notification: Notification) {
        guard let accountId = notification.userInfo?["account_id"] as? Int,
              let chatId = notification.userInfo?["chat_id"] as? Int else { return }

        NotificationManager.removeNotificationsForChat(chatId, accountId: accountId)
    }

    @objc private func handleIncomingMessageOnAnyAccount(_ notification: Notification) {
        NotificationManager.updateBadgeCounters()
        Task { [weak self] in
            guard let self,
                  let accountId = notification.userInfo?["account_id"] as? Int,
                  let chatId = notification.userInfo?["chat_id"] as? Int,
                  let messageId = notification.userInfo?["message_id"] as? Int
            else { return }
            await notifyIncomingMessage(messageId, chatId: chatId, accountId: accountId)
        }
    }

    public func notifyIncomingMessage(_ msgId: Int, chatId: Int, accountId: Int) async {
        let eventContext = dcAccounts.get(id: accountId)
        let chat = eventContext.getChat(chatId: chatId)
        let msg = eventContext.getMessage(id: msgId)
        if let content = UNMutableNotificationContent(forMessage: msg, chat: chat, context: eventContext) {
            try? await Self.unc.add(UNNotificationRequest(identifier: content.idOrRandomUUID(), content: content, trigger: inOneSecond))
        }
    }

    @objc private func handleIncomingReaction(_ notification: Notification) {
        Task { [weak self] in
            guard let self,
                  let accountId = notification.userInfo?["account_id"] as? Int,
                  let msgId = notification.userInfo?["msg_id"] as? Int,
                  let reaction = notification.userInfo?["reaction"] as? String,
                  let contact = notification.userInfo?["contact_id"] as? Int
            else { return }
            await notifyIncomingReaction(reaction, from: contact, msgId: msgId, accountId: accountId)
        }
    }

    public func notifyIncomingReaction(_ reaction: String, from contactId: Int, msgId: Int, accountId: Int) async {
        let eventContext = dcAccounts.get(id: accountId)
        let msg = eventContext.getMessage(id: msgId)
        let chat = eventContext.getChat(chatId: msg.chatId)
        if let content = UNMutableNotificationContent(forReaction: reaction, from: contactId, msg: msg, chat: chat, context: eventContext) {
            try? await Self.unc.add(UNNotificationRequest(identifier: content.idOrRandomUUID(), content: content, trigger: inOneSecond))
        }
    }

    @objc private func handleIncomingWebxdcNotify(_ notification: Notification) {
        Task { [weak self] in
            guard let self,
                  let accountId = notification.userInfo?["account_id"] as? Int,
                  let msgId = notification.userInfo?["msg_id"] as? Int,
                  let text = notification.userInfo?["text"] as? String
            else { return }
            await notifyIncomingWebxdcNotify(text, msgId: msgId, accountId: accountId)
        }
    }

    public func notifyIncomingWebxdcNotify(_ webxdcNotification: String, msgId: Int, accountId: Int) async {
        let eventContext = dcAccounts.get(id: accountId)
        let msg = eventContext.getMessage(id: msgId)
        let chat = eventContext.getChat(chatId: msg.chatId)
        if let content = UNMutableNotificationContent(forWebxdcNotification: webxdcNotification, msg: msg, chat: chat, context: eventContext) {
            try? await Self.unc.add(UNNotificationRequest(identifier: content.idOrRandomUUID(), content: content, trigger: inOneSecond))
        }
    }
}

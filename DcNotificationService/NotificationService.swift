import UserNotifications
import CallKit
import DcCore

/// If one profile is stuck on connecting then all notifications are delayed by this amount of seconds
/// so this is a tradeoff between how long we want to try to gather notifications and how long we want to let the user wait
/// in case they have a broken profile.
let fetchTimeout = 15.0

class NotificationService: UNNotificationServiceExtension {
    let dcAccounts = DcAccounts.shared
    let unc = UNUserNotificationCenter.current()

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        Task {
            await didReceive(request, withContentHandler: contentHandler)
        }
    }

    func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) async {
        let nowTimestamp = Date().timeIntervalSince1970
        UserDefaults.pushToDebugArray("🤜")

        let dnc = DarwinNotificationCenter.current
        if await dnc.didReply(.appRunningConfirmation, to: .appRunningQuestion, timeout: .now() + .seconds(2)) {
            UserDefaults.pushToDebugArray("ABORT4_AS_MAIN_RUNS")
            contentHandler(silentNotification())
            return
        }
        if UserDefaults.nseFetching {
            UserDefaults.pushToDebugArray("ABORT5_AS_NSE_RUNS")
            contentHandler(silentNotification())
            return
        }
        UserDefaults.setNseFetching(for: fetchTimeout)

        dcAccounts.openDatabase(writeable: false)
        let eventEmitter = dcAccounts.getEventEmitter()

        // Queue the bestAttempt notification in case the NSE is killed due to memory usage
        try? await unc.add(UNNotificationRequest(
            identifier: "best_attempt",
            content: request.content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: fetchTimeout + 1, repeats: false)
        ))

        // Log to debug array when memory is low
        let memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .critical)
        memoryPressureSource.setEventHandler { [weak memoryPressureSource] in
            guard let memoryPressureSource, !memoryPressureSource.isCancelled else { return }
            memoryPressureSource.cancel()
            UserDefaults.pushToDebugArray("ERR5_LOW_MEM")
        }
        memoryPressureSource.activate()

        let eventEmitterTask = Task {
            let inOneSecond = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            while true {
                guard let event = eventEmitter.getNextEvent() else { break }
                if event.id == DC_EVENT_ACCOUNTS_BACKGROUND_FETCH_DONE { break }
                if event.id == DC_EVENT_INCOMING_MSG {
                    let dcContext = dcAccounts.get(id: event.accountId)
                    let chat = dcContext.getChat(chatId: event.data1Int)
                    let msg = dcContext.getMessage(id: event.data2Int)
                    if let content = UNMutableNotificationContent(forMessage: msg, chat: chat, context: dcContext) {
                        try? await unc.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: inOneSecond))
                    }
                } else if event.id == DC_EVENT_INCOMING_REACTION {
                    let dcContext = dcAccounts.get(id: event.accountId)
                    let msg = dcContext.getMessage(id: event.data2Int)
                    let chat = dcContext.getChat(chatId: msg.chatId)
                    if let content = UNMutableNotificationContent(forReaction: event.data2String, from: event.data1Int, msg: msg, chat: chat, context: dcContext) {
                        try? await unc.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: inOneSecond))
                    }
                } else if event.id == DC_EVENT_INCOMING_WEBXDC_NOTIFY {
                    let dcContext = dcAccounts.get(id: event.accountId)
                    let msg = dcContext.getMessage(id: event.data2Int)
                    let chat = dcContext.getChat(chatId: msg.chatId)
                    if let content = UNMutableNotificationContent(forWebxdcNotification: event.data2String, msg: msg, chat: chat, context: dcContext) {
                        try? await unc.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: inOneSecond))
                    }
                } else if event.id == DC_EVENT_INCOMING_CALL {
                    UserDefaults.pushToDebugArray("☎️")
                    let payload: [String: Any] = [
                        "event_id": Int(DC_EVENT_INCOMING_CALL),
                        "account_id": event.accountId,
                        "message_id": event.data1Int,
                        "place_call_info": event.data2String,
                        "has_video": event.data2Int == 1,
                    ]
                    if !canUseCallKit {
                        UserDefaults.shared?.set(payload, forKey: UserDefaults.incomingCallPayloadKey)
                        let dcContext = dcAccounts.get(id: event.accountId)
                        let msg = dcContext.getMessage(id: event.data2Int)
                        let chat = dcContext.getChat(chatId: msg.chatId)
                        if let content = UNMutableNotificationContent(forIncomingCallMsg: msg, chat: chat, context: dcContext) {
                            let request = UNNotificationRequest(identifier: "incoming-call", content: content, trigger: nil)
                            try? await unc.add(request)
                        }
                    } else {
                        // reportNewIncomingVoIPPushPayload ends up in didReceiveIncomingPushWith in the main app
                        CXProvider.reportNewIncomingVoIPPushPayload(payload) { error in
                            if let error {
                                UserDefaults.pushToDebugArray("ERR6 " + error.localizedDescription)
                            } else {
                                UserDefaults.pushToDebugArray("OK2")
                            }
                        }
                    }
                } else if event.id == DC_EVENT_CALL_ENDED || event.id == DC_EVENT_INCOMING_CALL_ACCEPTED {
                    UserDefaults.pushToDebugArray(event.id == DC_EVENT_CALL_ENDED ? "☎️ENDED" : "☎️ACCEPTED")
                    UserDefaults.shared?.set(nil, forKey: UserDefaults.incomingCallPayloadKey)
                    if #available(iOSApplicationExtension 14.5, *), canUseCallKit {
                        // reportNewIncomingVoIPPushPayload ends up in didReceiveIncomingPushWith in the main app
                        CXProvider.reportNewIncomingVoIPPushPayload([
                            "event_id": Int(event.id),
                            "account_id": event.accountId,
                            "message_id": event.data1Int,
                        ] as [String: Any]) { error in
                            if let error {
                                UserDefaults.pushToDebugArray("ERR7 " + error.localizedDescription)
                            } else {
                                UserDefaults.pushToDebugArray("OK4")
                            }
                        }
                    }
                } else if event.id == DC_EVENT_MSGS_NOTICED {
                    let noticedThreadId = "\(event.accountId)-\(event.data1Int)"
                    let pendingNotificationIds = await unc.pendingNotificationRequests()
                        .filter { $0.content.threadIdentifier == noticedThreadId }
                        .map { $0.identifier }
                    unc.removePendingNotificationRequests(withIdentifiers: pendingNotificationIds)
                    let deliveredNotificationIds = await unc.deliveredNotifications()
                        .filter { $0.request.content.threadIdentifier == noticedThreadId }
                        .map { $0.request.identifier }
                    unc.removeDeliveredNotifications(withIdentifiers: deliveredNotificationIds)
                }
            }
        }

        if dcAccounts.backgroundFetch(timeout: UInt64(fetchTimeout)) {
            unc.removePendingNotificationRequests(withIdentifiers: ["best_attempt"])
            unc.removeDeliveredNotifications(withIdentifiers: ["best_attempt"])
            UserDefaults.pushToDebugArray(String(format: "OK2 %.3fs", Date().timeIntervalSince1970 - nowTimestamp))
        } else {
            UserDefaults.pushToDebugArray("ERR3_CORE")
            // We assume backgroundFetch returned false faster than the eventEmitterTask started
            // and that hasn't called eventEmitter.getNextEvent() yet, because if it did, that task
            // will be stuck as no events will ever be sent to the eventEmitter.
            eventEmitterTask.cancel()
        }

        UserDefaults.setNseFetchingDone()

        // This silent notification updates the badge number
        let silentNotification = silentNotification()
        silentNotification.badge = dcAccounts.getFreshMessagesCount() as NSNumber
        dcAccounts.closeDatabase()
        UserDefaults.shared?.set(true, forKey: UserDefaults.hasExtensionAttemptedToSend) // force UI updates in case app was suspended
        contentHandler(silentNotification)
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.

        // For Delta Chat, it is just fine to do nothing - assume eg. bad network or mail servers not reachable,
        // then a "You have new messages" is the best that can be done.
        UserDefaults.pushToDebugArray("ERR4_TIME")
        UserDefaults.setNseFetchingDone()
    }

    /// Do not show anything; requires `com.apple.developer.usernotifications.filtering` entitlement
    private func silentNotification() -> UNMutableNotificationContent {
        UNMutableNotificationContent()
    }
}

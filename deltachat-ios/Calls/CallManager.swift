import CallKit
import UserNotifications
import DcCore

let canVideoCalls = true

enum CallDirection {
    case incoming
    case outgoing
}

class DcCall {
    let contextId: Int
    let chatId: Int
    let uuid: UUID
    let direction: CallDirection
    var messageId: Int?        // set for incoming calls or after dc_place_outgoing_call()
    var placeCallInfo: String? // payload from caller given to dc_place_outgoing_call()
    var callAcceptedHere: Bool // for multidevice, stop ringing elsewhere

    init(contextId: Int, chatId: Int, uuid: UUID, direction: CallDirection, messageId: Int? = nil, placeCallInfo: String? = nil) {
        self.contextId = contextId
        self.chatId = chatId
        self.uuid = uuid
        self.direction = direction
        self.messageId = messageId
        self.placeCallInfo = placeCallInfo
        self.callAcceptedHere = false
    }
}

class CallManager: NSObject {
    static let shared = CallManager()

    private let voIPPushManager: VoIPPushManager
    private let provider: CXProvider
    private let callController: CXCallController
    private let callObserver: CXCallObserver
    private var currentCall: DcCall?

    override init() {
        voIPPushManager = VoIPPushManager()
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = canVideoCalls
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        provider = CXProvider(configuration: configuration)
        callController = CXCallController()
        callObserver = CXCallObserver()

        super.init()

        provider.setDelegate(self, queue: nil)
        callObserver.setDelegate(self, queue: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(CallManager.handleIncomingCallEvent(_:)), name: Event.incomingCall, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(CallManager.handleIncomingCallAcceptedEvent(_:)), name: Event.incomingCallAccepted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(CallManager.handleCallEndedEvent(_:)), name: Event.callEnded, object: nil)
    }

    func placeOutgoingCall(dcContext: DcContext, dcChat: DcChat) {
        if isCalling() {
            logger.warning("already calling")
            return
        }

        let uuid = UUID()
        currentCall = DcCall(contextId: dcContext.id, chatId: dcChat.id, uuid: uuid, direction: .outgoing)

        if canUseCallKit {
            let nameToDisplay = dcChat.name
            let handle = CXHandle(type: .generic, value: nameToDisplay)
            let startCallAction = CXStartCallAction(call: uuid, handle: handle)
            startCallAction.isVideo = canVideoCalls

            let transaction = CXTransaction(action: startCallAction)
            callController.request(transaction) { [currentCall] error in
                if let error {
                    logger.error("☎️ failed to start call: \(error.localizedDescription)")
                } else if let currentCall {
                    logger.info("☎️ call started to \(nameToDisplay)")
                    DispatchQueue.main.async {
                        CallWindow.shared?.showCallUI(for: currentCall)
                    }
                }
            }
        } else if let currentCall {
            DispatchQueue.main.async {
                CallWindow.shared?.showCallUI(for: currentCall)
            }
        }
    }

    @objc private func handleIncomingCallEvent(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }
        guard let accountId = ui["account_id"] as? Int,
              let msgId = ui["message_id"] as? Int,
              let placeCallInfo = ui["place_call_info"] as? String else { return }
        reportIncomingCall(accountId: accountId, msgId: msgId, placeCallInfo: placeCallInfo)
    }

    // this function is called from didReceiveIncomingPushWith
    // and needs to report an incoming call _immediately_ and _unconditionally_.
    // dispatching and conditions should be done by the caller
    func reportIncomingCall(accountId: Int, msgId: Int, placeCallInfo: String) {
        let dcContext = DcAccounts.shared.get(id: accountId)
        let dcMsg = dcContext.getMessage(id: msgId)
        let dcChat = dcContext.getChat(chatId: dcMsg.chatId)
        let name = dcChat.name
        let uuid = UUID()
        currentCall = DcCall(contextId: accountId, chatId: dcChat.id, uuid: uuid, direction: .incoming, messageId: msgId, placeCallInfo: placeCallInfo)

        if canUseCallKit {
            let update = CXCallUpdate()
            update.remoteHandle = CXHandle(type: .generic, value: name)
            update.supportsHolding = false
            update.supportsGrouping = false
            update.supportsUngrouping = false
            update.supportsDTMF = false
            update.hasVideo = canVideoCalls

            provider.reportNewIncomingCall(with: uuid, update: update) { error in
                if let error {
                    logger.info("☎️ failed to report incoming call: \(error.localizedDescription)")
                }
            }
        } else {
            let content = UNMutableNotificationContent(
                forIncomingCall: uuid,
                msg: dcMsg,
                chat: dcChat,
                context: dcContext
            )
            if let content {
                let request = UNNotificationRequest(identifier: "incoming-call", content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }
        }
    }

    @objc private func handleIncomingCallAcceptedEvent(_ notification: Notification) {
        guard let ui = notification.userInfo,
              let accountId = ui["account_id"] as? Int,
              let msgId = ui["message_id"] as? Int else { return }

        if let currentCall, currentCall.contextId == accountId, currentCall.messageId == msgId {
            if !currentCall.callAcceptedHere {
                logger.info("☎️ incoming call accepted on other device")
                let uuid = currentCall.uuid
                self.currentCall = nil  // avoid dcContext.endCall() being called
                endCallController(uuid: uuid)
            }

            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [
                "incoming-call"
            ])
        }
    }

    @objc private func handleCallEndedEvent(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }
        guard let accountId = ui["account_id"] as? Int,
              let msgId = ui["message_id"] as? Int else { return }
        if let currentCall, currentCall.contextId == accountId, currentCall.messageId == msgId {
            logger.info("☎️ call to end (\(accountId),\(msgId)) is the current call :)")
            endCallController(uuid: currentCall.uuid)

            // call is missed if
            // - not accepted elsewhere (currentCall would have been set to nil in handleIncomingCallAcceptedEvent)
            // - and not accepted here (check currentCall.callAcceptedHere)
            if !currentCall.callAcceptedHere, !canUseCallKit {
                let dcContext = DcAccounts.shared.get(id: accountId)
                let dcMsg = dcContext.getMessage(id: msgId)
                let dcChat = dcContext.getChat(chatId: dcMsg.chatId)
                let content = UNMutableNotificationContent(
                    forMissedCall: currentCall.uuid,
                    msg: dcMsg,
                    chat: dcChat,
                    context: dcContext
                )
                if let content {
                    let id = "missed-call-" + currentCall.uuid.uuidString
                    let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                }
            }
        } else {
            logger.info("☎️ call (\(accountId),\(msgId)) already ended")
        }

        DispatchQueue.main.async {
            CallWindow.shared?.quitCallUI()
        }

        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [
            "incoming-call"
        ])
    }

    func endCallControllerAndHideUI() {
        guard let currentCall else { return }

        endCallController(uuid: currentCall.uuid)

        DispatchQueue.main.async {
            CallWindow.shared?.quitCallUI()
        }
    }

    func endCallControllerIfUnacceptedIncoming() {
        guard let currentCall else { return }

        if currentCall.direction == .incoming && !currentCall.callAcceptedHere {
            endCallController(uuid: currentCall.uuid)
        }
    }

    private func endCallController(uuid: UUID) {
        if canUseCallKit {
            let endCallAction = CXEndCallAction(call: uuid)
            let transaction = CXTransaction(action: endCallAction)

            // requesting CXEndCallAction will result in provider(CXEndCallAction) being called below, which results in dcContext.endCall() for valid objects
            callController.request(transaction) { error in
                if let error {
                    logger.info("☎️ error ending call: \(error.localizedDescription)")
                } else {
                    logger.info("☎️ call ended successfully")
                }
            }
        } else if let currentCall, let messageId = currentCall.messageId {
            let dcContext = DcAccounts.shared.get(id: currentCall.contextId)
            self.currentCall = nil
            dcContext.endCall(msgId: messageId)
        }
    }

    func isCalling() -> Bool {
        if canUseCallKit {
            for call in callObserver.calls {
                if !call.hasEnded {
                    return true
                }
            }
            return false
        } else {
            return currentCall != nil
        }
    }


    func answerIncomingCall(withUUID uuid: UUID) {
        guard currentCall?.uuid == uuid else { return }
        answerIncomingCall()
    }
    func answerIncomingCall(forMessage msgId: Int, chatId: Int, contextId: Int) {
        guard currentCall?.messageId == msgId, currentCall?.chatId == chatId, currentCall?.contextId == contextId else { return }
        answerIncomingCall()
    }
    func answerIncomingCall() {
        guard let currentCall else { return }
        CallWindow.shared?.showCallUI(for: currentCall)
    }
}

extension CallManager: CXProviderDelegate {
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        logger.info("☎️ call accepted pressed")
        DispatchQueue.main.async {
            CallManager.shared.answerIncomingCall()
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        logger.info("☎️ call ended pressed")
        if let currentCall, let messageId = currentCall.messageId {
            let dcContext = DcAccounts.shared.get(id: currentCall.contextId)
            self.currentCall = nil
            dcContext.endCall(msgId: messageId)
        }
        action.fulfill()
    }

    func providerDidReset(_ provider: CXProvider) {
        logger.info("☎️ provider did reset")
    }
}

extension CallManager: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        logger.info("☎️ call changed: \(call)")
    }
}

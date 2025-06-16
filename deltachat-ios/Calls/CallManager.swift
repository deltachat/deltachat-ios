import CallKit
import DcCore

let canVideoCalls = true

struct DcCall {
    let contextId: Int
    let messageId: Int
    let incoming: Bool
    let uuid: UUID
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
        NotificationCenter.default.addObserver(self, selector: #selector(CallManager.handleCallEndedEvent(_:)), name: Event.callEnded, object: nil)
    }

    func placeOutgoingCall(dcContext: DcContext, dcChat: DcChat) {
        if isCalling() {
            logger.warning("already calling")
            return
        }

        let messageId = dcContext.placeOutgoingCall(chatId: dcChat.id)
        let uuid = UUID()
        currentCall = DcCall(contextId: dcContext.id, messageId: messageId, incoming: false, uuid: uuid)

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
    }

    @objc private func handleIncomingCallEvent(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }
        guard let accountId = ui["account_id"] as? Int,
              let msgId = ui["message_id"] as? Int else { return }
        reportIncomingCall(accountId: accountId, msgId: msgId)
    }

    @objc private func handleCallEndedEvent(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }
        guard let accountId = ui["account_id"] as? Int,
              let msgId = ui["message_id"] as? Int else { return }
        if let currentCall, currentCall.contextId == accountId, currentCall.messageId == msgId {
            logger.info("☎️ call to end (\(accountId),\(msgId)) is the current call :)")
            endCall(uuid: currentCall.uuid)
        } else {
            logger.info("☎️ call (\(accountId),\(msgId)) already ended")
        }
        
        DispatchQueue.main.async {
            CallWindow.shared?.endCall()
        }
    }

    // this function is called from didReceiveIncomingPushWith
    // and needs to report an incoming call _immediately_ and _unconditionally_.
    // dispatching and conditions should be done by the caller
    func reportIncomingCall(accountId: Int, msgId: Int) {
        let dcContext = DcAccounts.shared.get(id: accountId)
        let dcMsg = dcContext.getMessage(id: msgId)
        let dcChat = dcContext.getChat(chatId: dcMsg.chatId)
        let name = dcChat.name
        let uuid = UUID()
        currentCall = DcCall(contextId: accountId, messageId: msgId, incoming: true, uuid: uuid)

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
    }

    func endCall(uuid: UUID) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)

        callController.request(transaction) { error in
            if let error {
                logger.info("☎️ error ending call: \(error.localizedDescription)")
            } else {
                logger.info("☎️ call ended successfully")
            }
        }
    }

    func isCalling() -> Bool {
        for call in callObserver.calls {
            if !call.hasEnded {
                return true
            }
        }
        return false
    }
}

extension CallManager: CXProviderDelegate {
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        logger.info("☎️ call accepted pressed")
        if let currentCall {
            // TODO: in the future, this should be "accept call"
            let dcContext = DcAccounts.shared.get(id: currentCall.contextId)
            dcContext.endCall(msgId: currentCall.messageId)
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        logger.info("☎️ call ended pressed")
        if let currentCall {
            let dcContext = DcAccounts.shared.get(id: currentCall.contextId)
            let messageId = currentCall.messageId
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

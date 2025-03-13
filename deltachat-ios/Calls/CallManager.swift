import CallKit
import DcCore

class DcCall {
    let contextId: Int
    let messageId: Int
    let incoming: Bool

    init(incoming: Bool, contextId: Int, messageId: Int) {
        self.incoming = incoming
        self.contextId = contextId
        self.messageId = messageId
    }
}

class CallManager: NSObject {
    static let shared = CallManager()

    private let voIPPushManager: VoIPPushManager
    private let provider: CXProvider
    private let callObserver: CXCallObserver
    private var currentCall: DcCall?

    override init() {
        voIPPushManager = VoIPPushManager()
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = true
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        provider = CXProvider(configuration: configuration)
        callObserver = CXCallObserver()

        super.init()

        provider.setDelegate(self, queue: nil)
        callObserver.setDelegate(self, queue: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(CallManager.handleIncomingCallEvent(_:)), name: Event.incomingCall, object: nil)
    }

    func placeOutgoingCall(dcContext: DcContext, dcChat: DcChat) {
        if isCalling() {
            logger.warning("already calling")
            return
        }

        let messageId = dcContext.placeOutgoingCall(chatId: dcChat.id)
        currentCall = DcCall(incoming: false, contextId: dcContext.id, messageId: messageId)

        let callController = CXCallController()
        let uuid = UUID()
        let nameToDisplay = dcChat.name
        let handle = CXHandle(type: .generic, value: nameToDisplay)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.isVideo = true

        let transaction = CXTransaction(action: startCallAction)
        callController.request(transaction) { error in
            if let error = error {
                logger.error("Failed to start call: \(error.localizedDescription)")
            } else {
                logger.info("Call started to \(nameToDisplay)")
            }
        }
    }

    @objc private func handleIncomingCallEvent(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }
        guard let accountId = ui["account_id"] as? Int,
              let msgId = ui["message_id"] as? Int else { return }
        reportIncomingCall(accountId: accountId, msgId: msgId)
    }

    func reportIncomingCall(accountId: Int, msgId: Int) {
        if isCalling() {
            logger.warning("already calling")
            return
        }

        DispatchQueue.global().async { [weak self] in
            guard let self else { return }

            let dcContext = DcAccounts.shared.get(id: accountId)
            let dcMsg = dcContext.getMessage(id: msgId)
            let dcChat = dcContext.getChat(chatId: dcMsg.chatId)
            let name = dcChat.name
            currentCall = DcCall(incoming: true, contextId: accountId, messageId: msgId)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                let update = CXCallUpdate()
                update.remoteHandle = CXHandle(type: .generic, value: name)
                update.hasVideo = true

                provider.reportNewIncomingCall(with: UUID(), update: update) { error in
                    if let error = error {
                        logger.info("Failed to report incoming call: \(error.localizedDescription)")
                    }
                }
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
        logger.info("Call accepted")
        // Notify backend to start the call
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        logger.info("Call ended")
        action.fulfill()
        if let currentCall {
            let dcContext = DcAccounts.shared.get(id: currentCall.contextId)
            dcContext.endCall(msgId: currentCall.messageId)
        }
    }

    func providerDidReset(_ provider: CXProvider) {
        logger.info("provider did reset")
    }
}

extension CallManager: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        print("call changed: \(call)")
    }
}

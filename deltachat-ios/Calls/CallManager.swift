import CallKit
import PushKit
import DcCore

class PushManager: NSObject, PKPushRegistryDelegate {
    var pushRegistry: PKPushRegistry?

    func registerForVoIPPushes() {
        // registering for VoIP pushes is needed to enable the didReceiveIncomingPushWith callback,
        // which is called via reportNewIncomingVoIPPushPayload from the regular NSE
        pushRegistry = PKPushRegistry(queue: DispatchQueue.main)
        pushRegistry?.delegate = self
        pushRegistry?.desiredPushTypes = [.voIP]
    }

    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        // VoIP tokens are not used
        logger.info("VoIP token received")
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        let callInfo = payload.dictionaryPayload
        logger.info("didReceiveIncomingPushWith: \(callInfo)")
        guard let accountId = callInfo["account_id"] as? Int,
              let msgId = callInfo["message_id"] as? Int else { return }
        CallManager.shared.reportIncomingCall(accountId: accountId, msgId: msgId)
    }
}

class CallManager: NSObject, CXProviderDelegate {
    static let shared = CallManager()
    private let provider: CXProvider
    private let pushManager: PushManager

    override init() {
        pushManager = PushManager()
        pushManager.registerForVoIPPushes()

        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = true
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]

        provider = CXProvider(configuration: configuration)
        super.init()
        provider.setDelegate(self, queue: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(CallManager.handleIncomingCall(_:)), name: Event.incomingCall, object: nil)
    }

    func placeOutgoingCall(dcContext: DcContext, dcChat: DcChat) {
        _ = dcContext.placeOutgoingCall(chatId: dcChat.id)

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

    @objc private func handleIncomingCall(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }
        logger.info("handleIncomingCall: \(ui)")
        guard let accountId = ui["account_id"] as? Int,
              let msgId = ui["message_id"] as? Int else { return }
        reportIncomingCall(accountId: accountId, msgId: msgId)
    }

    func reportIncomingCall(accountId: Int, msgId: Int) {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }

            let dcContext = DcAccounts.shared.get(id: accountId)
            let dcMsg = dcContext.getMessage(id: msgId)
            let dcChat = dcContext.getChat(chatId: dcMsg.chatId)
            let name = dcChat.name

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

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        logger.info("Call accepted")
        // Notify backend to start the call
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        logger.info("Call ended")
        // Notify backend to end the call
        action.fulfill()
    }

    func providerDidReset(_ provider: CXProvider) {
        logger.info("provider did reset")
    }
}

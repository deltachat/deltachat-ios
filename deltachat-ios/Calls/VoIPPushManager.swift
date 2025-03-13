import PushKit

class VoIPPushManager: NSObject, PKPushRegistryDelegate {
    var pushRegistry: PKPushRegistry?

    override public init() {
        super.init()

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

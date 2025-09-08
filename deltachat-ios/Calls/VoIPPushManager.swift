import PushKit
import DcCore

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
        logger.info("☎️ voIP token received")
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        // we MUST report the incoming call immediately - so without dispatching to tother threads -
        // to reportNewIncomingCall() - otherwise we get a PushKit penalty that prevents us from handling future calls.
        // this is not theory, but happens during development :)
        logger.info("☎️ didReceiveIncomingPushWith")
        let callInfo = payload.dictionaryPayload
        guard let event = callInfo["event_id"] as? Int,
              let accountId = callInfo["account_id"] as? Int,
              let msgId = callInfo["message_id"] as? Int else { return }

        if event == DC_EVENT_INCOMING_CALL {
            guard let placeCallInfo = callInfo["place_call_info"] as? String else { return }
            CallManager.shared.reportIncomingCall(accountId: accountId, msgId: msgId, placeCallInfo: placeCallInfo)
        } else if event == DC_EVENT_CALL_ENDED || event == DC_EVENT_INCOMING_CALL_ACCEPTED {
            CallManager.shared.endCallControllerIfUnacceptedIncoming()
        } else {
            logger.error("unknown event: \(event)")
        }
    }
}

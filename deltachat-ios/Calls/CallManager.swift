import CallKit

class CallManager: NSObject, CXProviderDelegate {
    static let shared = CallManager()
    private let provider: CXProvider

    override init() {
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = true
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]

        provider = CXProvider(configuration: configuration)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    func reportIncomingCall(from caller: String) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: caller)
        update.hasVideo = true

        provider.reportNewIncomingCall(with: UUID(), update: update) { error in
            if let error = error {
                logger.info("Failed to report incoming call: \(error.localizedDescription)")
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

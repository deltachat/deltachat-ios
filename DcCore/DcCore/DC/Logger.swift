import Foundation
import OSLog

let logger = DcLogger()

public func getDcLogger() -> DcLogger {
    return logger
}

public class DcLogger {
    public static let subsystem = "chat.delta"
    static let category = "deltachat"
    let osLog: Logger

    static var enabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: UserDefaults.loggingEnabledKey) == nil {
                #if DEBUG
                return true
                #else
                return false
                #endif
            }
            return UserDefaults.standard.bool(forKey: UserDefaults.loggingEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaults.loggingEnabledKey) }
    }

    public init() {
        osLog = Logger(subsystem: DcLogger.subsystem, category: DcLogger.category)
    }

    public func error(_ message: String) {
        guard DcLogger.enabled else { return }
        osLog.error("❤️ \(message, privacy: .public)")
    }

    public func warning(_ message: String) {
        guard DcLogger.enabled else { return }
        osLog.warning("🧡 \(message, privacy: .public)")
    }

    public func info(_ message: String) {
        guard DcLogger.enabled else { return }
        osLog.info("💙 \(message, privacy: .public)")
    }

    #if DEBUG
    public func debug(_ message: String) {
        osLog.debug("💚 \(message, privacy: .public)")
    }
    #endif
}

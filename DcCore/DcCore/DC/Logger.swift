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

    public init() {
        osLog = Logger(subsystem: DcLogger.subsystem, category: DcLogger.category)
    }

    public func error(_ message: String) {
        osLog.error("❤️ \(message, privacy: .public)") // "public" is needed to show lines; core takes care of privacy
    }

    public func warning(_ message: String) {
        osLog.warning("🧡 \(message, privacy: .public)")
    }

    public func info(_ message: String) {
        osLog.notice("💙 \(message, privacy: .public)") // info() is not persisted
    }

    // debug() marked as DEBUG as these lines are for, well debugging. and should not being released. otherwise, use info()
    #if DEBUG
    public func debug(_ message: String) {
        osLog.debug("💚 \(message, privacy: .public)")
    }
    #endif
}

import Foundation
import OSLog

let logger = DcLogger()

public func getDcLogger() -> DcLogger {
    return logger
}

public class DcLogger {
    public static let subsystem = "chat.delta"
    static let category = "deltachat"
    let osLog: AnyObject?

    public init() {
        if #available(iOS 14.0, *) {
            osLog = Logger(subsystem: DcLogger.subsystem, category: DcLogger.category) as AnyObject
        } else {
            osLog = nil
        }
    }

    public func error(_ message: String) {
        if #available(iOS 14.0, *) {
            (osLog as? Logger)?.error("❤️ \(message, privacy: .public)") // "public" is needed to show lines; core takes care of privacy
        } else {
            os_log("❤️ %{public}s", log: .default, type: .error, message)
        }
    }

    public func warning(_ message: String) {
        if #available(iOS 14.0, *) {
            (osLog as? Logger)?.warning("🧡 \(message, privacy: .public)")
        } else {
            os_log("🧡 %{public}s", log: .default, type: .default /* there is no .warning */, message)
        }
    }

    public func info(_ message: String) {
        if #available(iOS 14.0, *) {
            (osLog as? Logger)?.notice("💙 \(message, privacy: .public)") // info() is not persisted
        } else {
            os_log("💙 %{public}s", log: .default, type: .default /* .default equals notice() and is persisted */, message)
        }
    }

    // debug() marked as DEBUG as these lines are for, well debugging. and should not being released. otherwise, use info()
    #if DEBUG
    public func debug(_ message: String) {
        if #available(iOS 14.0, *) {
            (osLog as? Logger)?.debug("💚 \(message, privacy: .public)")
        } else {
            os_log("💚 %{public}s", log: .default, type: .debug, message)
        }
    }
    #endif
}

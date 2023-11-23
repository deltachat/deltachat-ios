import Foundation

let logger = DcLogger()

public func getDcLogger() -> DcLogger {
    return logger
}

public class DcLogger {

    public init() {
    }

    public func debug(_ message: String) {
        log(heart: "💚", message: message)
    }

    public func info(_ message: String) {
        log(heart: "💙", message: message)
    }

    public func warning(_ message: String) {
        log(heart: "🧡", message: message)
    }

    public func error(_ message: String) {
        log(heart: "❤️", message: message)
    }

    private func log(heart: String, message: String) {
        print(DateUtils.getTimestamp(), heart, message)
    }
}

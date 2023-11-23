import Foundation

let logger = DcLogger()

public func getDcLogger() -> DcLogger {
    return logger
}

public class DcLogger {

    public init() {
    }

    public func debug(_ messages: Any...) {
        addLog(heart: "💚", messages: messages)
    }

    public func info(_ messages: Any...) {
        addLog(heart: "💙", messages: messages)
    }

    public func warning(_ messages: Any...) {
        addLog(heart: "🧡", messages: messages)
    }

    public func error(_ messages: Any...) {
        addLog(heart: "❤️", messages: messages)
    }

    private func addLog(heart: String, messages: Any...) {
        if messages is [String] {
            var messagesSummary = ""
            messages.forEach({(message) in
                messagesSummary = "\(messagesSummary) \(message)"
            })
            print(DateUtils.getTimestamp(), heart, messagesSummary)
        } else {
            print(DateUtils.getTimestamp(), heart, messages)
        }
    }
}

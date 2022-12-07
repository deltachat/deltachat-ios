import Foundation
import DcCore

class SimpleLogger: Logger {

    func verbose(_ messages: Any...) {
        addLog(heart: "💜", messages: messages)
    }

    func debug(_ messages: Any...) {
        addLog(heart: "💚", messages: messages)
    }

    func info(_ messages: Any...) {
        addLog(heart: "💙", messages: messages)
    }

    func warning(_ messages: Any...) {
        addLog(heart: "🧡", messages: messages)
    }

    func error(_ messages: Any...) {
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

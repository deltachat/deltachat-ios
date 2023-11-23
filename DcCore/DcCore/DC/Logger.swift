import Foundation

let logger = DcLogger()

public func getDcLogger() -> DcLogger {
    return logger
}

public class DcLogger {

    public init() {
    }

    public func debug(_ message: String) {
        print("💚 \(message)")
    }

    public func info(_ message: String) {
        print("💙 \(message)")
    }

    public func warning(_ message: String) {
        print("🧡 \(message)")
    }

    public func error(_ message: String) {
        print("❤️ \(message)")
    }
}

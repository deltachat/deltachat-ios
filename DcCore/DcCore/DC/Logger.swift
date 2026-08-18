import Foundation
import OSLog

let logger = DcLogger()

public func getDcLogger() -> DcLogger {
    return logger
}

public class DcLogger {
    public static let subsystem = "chat.delta"
    static let category = "deltachat"

    #if DEBUG
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
    public func debug(_ message: String) {
        osLog.debug("💚 \(message, privacy: .public)")
    }

    #else
    // Release builds log to a file in the shared app-group container instead of the
    // unified system log, so that messages are not readable from outside the sandbox
    // (Console.app via USB/Wi-Fi, sysdiagnose) but stay available to "View Log".
    // Only the last two executions are kept: on launch the current file becomes the
    // previous one, so after a crash the old log can still be inspected. To keep
    // long-running sessions bounded, the current file restarts after maxLogDuration.
    private static let maxLogDuration: TimeInterval = 60 * 60

    // previous file first, so that concatenating the contents gives chronological order
    static var logFileURLs: [URL] {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DatabaseHelper.applicationGroupIdentifier) else { return [] }
        return [container.appendingPathComponent("deltachat-log-old.txt"),
                container.appendingPathComponent("deltachat-log.txt")]
    }

    private let queue = DispatchQueue(label: "chat.delta.logger")
    private var fileDescriptor: Int32 = -1
    private var openedAt = Date()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    public init() {
        // only the main app starts a new execution; extensions append to the current log
        if !Bundle.main.bundlePath.hasSuffix(".appex"),
           let previousUrl = DcLogger.logFileURLs.first, let currentUrl = DcLogger.logFileURLs.last {
            try? FileManager.default.removeItem(at: previousUrl)
            try? FileManager.default.moveItem(at: currentUrl, to: previousUrl)
        }
        openCurrentLogFile()
    }

    deinit {
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
    }

    private func openCurrentLogFile() {
        guard var currentUrl = DcLogger.logFileURLs.last else { return }
        // O_APPEND keeps concurrent writes from the main app and the extensions intact
        fileDescriptor = open(currentUrl.path, O_WRONLY | O_APPEND | O_CREAT, 0o600)
        // keep the logs out of iCloud/iTunes backups; renaming preserves the flag
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? currentUrl.setResourceValues(resourceValues)
        openedAt = Date()
    }

    private func log(_ prefix: String, _ message: String) {
        queue.async { [self] in
            if fileDescriptor >= 0, Date().timeIntervalSince(openedAt) > DcLogger.maxLogDuration {
                close(fileDescriptor)
                // the previous-run log is even older, remove it as well for consistency
                for url in DcLogger.logFileURLs {
                    try? FileManager.default.removeItem(at: url)
                }
                openCurrentLogFile()
            }
            guard fileDescriptor >= 0,
                  let data = "[\(dateFormatter.string(from: Date()))] \(prefix) \(message)\n".data(using: .utf8) else { return }
            data.withUnsafeBytes { _ = write(fileDescriptor, $0.baseAddress, $0.count) }
        }
    }

    public func getLogText() -> String {
        return queue.sync {
            DcLogger.logFileURLs
                .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
                .joined()
        }
    }

    public func error(_ message: String) {
        log("❤️", message)
    }

    public func warning(_ message: String) {
        log("🧡", message)
    }

    public func info(_ message: String) {
        log("💙", message)
    }
    #endif
}

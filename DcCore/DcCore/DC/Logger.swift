import Foundation
public protocol Logger {
    func verbose(_ message: Any...)
    func debug(_ message: Any...)
    func info(_ message: Any...)
    func warning(_ message: Any...)
    func error(_ message: Any...)
}

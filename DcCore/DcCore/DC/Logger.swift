import Foundation
public protocol Logger {
    func verbose(_ message: String)
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

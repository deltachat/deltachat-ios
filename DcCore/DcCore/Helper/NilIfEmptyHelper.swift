public protocol NilIfEmptyHelper {
    var isEmpty: Bool { get }
}

public extension NilIfEmptyHelper {
    var nilIfEmpty: Self? {
        isEmpty ? nil : self
    }
}

extension Data: NilIfEmptyHelper {}
extension String: NilIfEmptyHelper {}

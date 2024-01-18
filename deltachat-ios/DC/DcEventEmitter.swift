import Foundation

/// Opaque object that is used to get events from a single context.
///
/// See [dc_event_emitter_t Class Reference](https://c.delta.chat/classdc__event__emitter__t.html)
public class DcEventEmitter {
    private var eventEmitterPointer: OpaquePointer?

    // takes ownership of specified pointer
    public init(eventEmitterPointer: OpaquePointer?) {
        self.eventEmitterPointer = eventEmitterPointer
    }

    public func getNextEvent() -> DcEvent? {
        guard let eventPointer = dc_get_next_event(eventEmitterPointer) else { return nil }
        return DcEvent(eventPointer: eventPointer)
    }

    deinit {
        dc_event_emitter_unref(eventEmitterPointer)
    }
}

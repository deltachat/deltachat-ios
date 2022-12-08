import Foundation

public class AtomicBoolean {
    private var val: UInt8 = 0
    public init(initialValue: Bool) {
        self.val = (initialValue == false ? 0 : 1)
    }


    public func set(value: Bool) {
        if value {
            OSAtomicTestAndSet(7, &val)
        } else {
            OSAtomicTestAndClear(7, &val)
        }
    }
    
  public func getAndSet(value: Bool) -> Bool {
    if value {
      return  OSAtomicTestAndSet(7, &val)
    } else {
      return  OSAtomicTestAndClear(7, &val)
    }
  }

  public func get() -> Bool {
    return val != 0
  }
}

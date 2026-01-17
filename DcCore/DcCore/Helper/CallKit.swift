#if targetEnvironment(simulator)
public let canUseCallKit = false
#else
public let canUseCallKit = true
#endif

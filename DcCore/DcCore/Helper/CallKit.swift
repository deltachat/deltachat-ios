#if targetEnvironment(simulator)
public let canUseCallKit = false
#else
public let canUseCallKit = Locale.current.regionCode != "CN"
#endif

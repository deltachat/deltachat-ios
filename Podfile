target 'deltachat-ios' do
  platform :ios, '10.0'
  use_frameworks!
  swift_version = '4.2'

  # ignore all warnings from all dependencies
  inhibit_all_warnings!

  pod 'SwiftLint'
  pod 'SwiftFormat/CLI'
  # pod 'openssl-ios-bitcode'
  pod 'ReachabilitySwift'
  pod 'UICircularProgressRing'
  pod 'SwiftyBeaver'
  pod 'DBDebugToolkit'
  pod 'InputBarAccessoryView'
  pod 'SCSiriWaveformView'
  pod 'SDWebImage', '~> 5.9.1'
  target 'deltachat-iosTests' do
    inherit! :search_paths
    # Pods for testing
  end
end

target 'DcShare' do
  platform :ios, '10.0'
  use_frameworks!
  swift_version = '4.2'

  # ignore all warnings from all dependencies
  inhibit_all_warnings!

  pod 'SDWebImage', '~> 5.9.1'
end

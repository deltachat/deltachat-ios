target 'deltachat-ios' do
  platform :ios, '10.0'
  use_frameworks!
  swift_version = '4.2'

  # ignore all warnings from all dependencies
  inhibit_all_warnings!

  pod 'Swifter'
  pod 'SwiftLint'
  pod 'SwiftFormat/CLI'
  # pod 'openssl-ios-bitcode'
  pod 'ReachabilitySwift'
  pod 'SwiftyBeaver'
  pod 'SCSiriWaveformView'
  pod 'SDWebImage', '~> 5.9.1'
  pod 'SDWebImageWebPCoder'
  pod 'SDWebImageSVGKitPlugin'
  pod 'SVGKit', :git => 'https://github.com/SVGKit/SVGKit.git', :branch => '3.x'
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
  pod 'SDWebImageWebPCoder'
end

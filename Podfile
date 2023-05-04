target 'deltachat-ios' do
  platform :ios, '11.0'
  use_frameworks!
  swift_version = '5'

  # ignore all warnings from all dependencies
  inhibit_all_warnings!

  pod 'Swifter', :git => 'https://github.com/httpswift/swifter.git', :branch => 'stable'
  pod 'SwiftLint'
  pod 'SwiftFormat/CLI'
  # pod 'openssl-ios-bitcode'
  pod 'ReachabilitySwift'
  pod 'SCSiriWaveformView'
  pod 'SDWebImage'
  pod 'SDWebImageWebPCoder'
  pod 'SDWebImageSVGKitPlugin'
  pod 'SVGKit', :git => 'https://github.com/SVGKit/SVGKit.git', :branch => '3.x'
  target 'deltachat-iosTests' do
    inherit! :search_paths
    # Pods for testing
  end
end

target 'DcShare' do
  platform :ios, '11.0'
  use_frameworks!
  swift_version = '5'

  # ignore all warnings from all dependencies
  inhibit_all_warnings!

  pod 'SDWebImage'
  pod 'SDWebImageWebPCoder'
end

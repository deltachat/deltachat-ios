platform :ios, '11.0'
use_frameworks!

# ignore all warnings from all dependencies
inhibit_all_warnings!

target 'deltachat-ios' do
  pod 'Swifter', :git => 'https://github.com/httpswift/swifter.git', :branch => 'stable'
  pod 'SwiftLint'
  pod 'SwiftFormat/CLI'
  # pod 'openssl-ios-bitcode'
  pod 'ReachabilitySwift'
  pod 'SCSiriWaveformView'
  pod 'SDWebImage', :modular_headers => true
  pod 'SDWebImageWebPCoder', :modular_headers => true
  pod 'SDWebImageSVGKitPlugin'
  pod 'SVGKit', :modular_headers => true
  target 'deltachat-iosTests' do
    inherit! :search_paths
    # Pods for testing
  end
end

target 'DcShare' do
  pod 'SDWebImage', :modular_headers => true
  pod 'SDWebImageWebPCoder', :modular_headers => true
end

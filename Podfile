platform :ios, '13.0'
use_frameworks!

# ignore all warnings from all dependencies
inhibit_all_warnings!

target 'deltachat-ios' do
  pod 'SwiftLint'
  pod 'SwiftFormat/CLI'
  # pod 'openssl-ios-bitcode'
  pod 'ReachabilitySwift'
  pod 'SCSiriWaveformView'
  pod 'SDWebImage', :modular_headers => true
  pod 'SDWebImageWebPCoder', :modular_headers => true
  pod 'SDWebImageSVGKitPlugin'
  pod 'SVGKit', :modular_headers => true
  pod 'MCEmojiPicker', :git => 'https://github.com/deltachat/MCEmojiPicker', :branch => 'main'

end

target 'DcShare' do
  pod 'SDWebImage', :modular_headers => true
  pod 'SDWebImageWebPCoder', :modular_headers => true
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = "13.0"
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
    end
  end
end

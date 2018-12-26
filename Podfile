target 'deltachat-ios' do
  use_frameworks!
  pod 'openssl-ios-bitcode', '1.0.210'
  pod 'MessageKit', '1.0.0'
  pod 'Differ'
  post_install do |installer|
      installer.pods_project.targets.each do |target|
          if target.name == 'MessageKit'
              target.build_configurations.each do |config|
                  config.build_settings['SWIFT_VERSION'] = '4.0'
              end
          end
      end
  end
end

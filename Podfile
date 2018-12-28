target 'deltachat-ios' do
  use_frameworks!
  pod 'openssl-ios-bitcode', '1.0.210'
  pod 'ReachabilitySwift'
  pod 'QuickTableViewController'
  pod 'JGProgressHUD'
  pod 'SwiftyBeaver'
  pod 'DBDebugToolkit'
  pod 'MessageKit', '2.0.0'
  post_install do |installer|
      installer.pods_project.targets.each do |target|
          if target.name == 'MessageKit'
              target.build_configurations.each do |config|
                  config.build_settings['SWIFT_VERSION'] = '4.2'
              end
          end
      end
  end
end

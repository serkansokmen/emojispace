platform :ios, '11.0'

target 'emojispace' do
    use_frameworks!

    pod 'Cartography'
    pod 'ChameleonFramework'
    pod 'FontAwesome.swift', :git => 'https://github.com/thii/FontAwesome.swift', :branch => 'master'
    pod 'NextLevel', '~> 0.4.0'
    pod 'Hero'

    post_install do |installer|
        installer.pods_project.targets.each do |target|
            target.build_configurations.each do |config|
                config.build_settings['SWIFT_VERSION'] = '3.2'
                config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.10'
            end
        end
    end

end


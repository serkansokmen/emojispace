platform :ios, '11.0'

target 'emojispace' do
    use_frameworks!

    pod 'Cartography', :git => 'https://github.com/robb/Cartography', :branch => 'master'
    pod 'ChameleonFramework', :git => 'https://github.com/ViccAlexander/Chameleon', :branch => 'master'
    pod 'FontAwesome.swift', :git => 'https://github.com/thii/FontAwesome.swift', :branch => 'master'
    pod 'Hero'
    pod 'ImagePicker'

    post_install do |installer|
        installer.pods_project.targets.each do |target|
            target.build_configurations.each do |config|
                config.build_settings['SWIFT_VERSION'] = '3.2'
                config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.10'
            end
        end
    end

end


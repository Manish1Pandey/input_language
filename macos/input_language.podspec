#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint input_language.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'input_language'
  s.version          = '0.1.0'
  s.summary          = 'Active keyboard / input language detection for Flutter.'
  s.description      = <<-DESC
Reads and observes the active keyboard / input language (UITextInputMode on iOS, Text Input Sources on macOS).
                       DESC
  s.homepage         = 'https://github.com/Manish1Pandey/input_language'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Manish Kumar Panday'

  s.source           = { :path => '.' }
  s.source_files     = 'input_language/Sources/input_language/**/*.swift'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = { 'input_language_privacy' => ['input_language/Sources/input_language/Resources/PrivacyInfo.xcprivacy'] }

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end

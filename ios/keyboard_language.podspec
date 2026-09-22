#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint keyboard_language.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'keyboard_language'
  s.version          = '0.1.0'
  s.summary          = 'Active keyboard / input language detection for Flutter.'
  s.description      = <<-DESC
Reads and observes the active keyboard / input language (UITextInputMode on iOS, Text Input Sources on macOS).
                       DESC
  s.homepage         = 'https://github.com/Manish1Pandey/keyboard_language'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Manish Kumar Panday'
  s.source           = { :path => '.' }
  s.source_files     = 'keyboard_language/Sources/keyboard_language/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = { 'keyboard_language_privacy' => ['keyboard_language/Sources/keyboard_language/Resources/PrivacyInfo.xcprivacy'] }
end

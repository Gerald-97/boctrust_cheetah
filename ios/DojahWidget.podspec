Pod::Spec.new do |s|
  s.name = 'DojahWidget'
  s.version = '1.1.17'
  s.summary = 'DojahWidget SDK for Pod projects.'
  s.homepage = 'https://github.com/dojah-inc/sdk-swift.git'
  s.license = { :type => 'MIT', :file => 'vendor/dojah-widget/LICENSE' }
  s.author = { 'Dojah' => 'dojah@dojah.io' }
  s.source = {
    :git => 'https://github.com/dojah-inc/sdk-swift.git',
    :commit => '46f11f2938f4b70fe0cde915b68d34a5d712ba8c'
  }
  s.platform = :ios, '14.0'
  s.swift_version = '5.0'
  s.source_files = 'vendor/dojah-widget/Sources/**/*.{swift,h}'
  s.resource_bundles = {
    'DojahWidgetResources' => [
      'vendor/dojah-widget/Sources/DojahWidget/Resources/**/*',
      'vendor/dojah-widget/Sources/DojahWidget/Utilities/Components/**/*.{xib}'
    ]
  }
  s.dependency 'HorizonCalendar', '~> 1.16.0'
  s.dependency 'lottie-ios', '~> 4.5.2'
  # Dojah 1.1.17 pins 10.52.2, which does not compile with Xcode 26.6.
  # Realm guarantees API compatibility across 10.x; 10.54.6 supports Xcode 26.
  s.dependency 'RealmSwift', '10.54.6'
  s.dependency 'IQKeyboardManagerSwift', '~> 7.1.1'
  s.dependency 'Kingfisher', '~> 7.12.0'
  s.dependency 'GooglePlaces', '~> 8.5.0'
  s.static_framework = true
end

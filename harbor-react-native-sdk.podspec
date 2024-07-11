# harbor-react-native-sdk.podspec

require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "harbor-react-native-sdk"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = <<-DESC
                  react-native-harbor-sdk
                   DESC
  s.homepage     = "https://github.com/github_account/harbor-react-native-sdk"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.authors      = { "Lucas Diez de Medina" => "lucas@theluxergroup.com" }
  s.platforms    = { :ios => "9.0" }
  s.source       = { :git => "https://github.com/github_account/harbor-react-native-sdk.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,c,cc,cpp,m,mm,swift}"
  s.requires_arc = true

  s.dependency "React"
  s.dependency "HarborLockersSDK", '1.0.21'
  # ...
  # s.dependency "..."
end


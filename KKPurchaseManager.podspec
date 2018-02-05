Pod::Spec.new do |s|
  s.name             = "KKPurchaseManager"
  s.version          = "0.1.0"
  s.license          = {:type => 'Apache 2.0', :file => "LICENSE.txt"}
  s.summary          = "A facade that manipulates StoreKit APIs to help the In-App Purchase flow."
  s.description   = <<-DESC
  KKBOX's IAP help that works on Apple platforms such as iOS, macOS, and tvOS.
                       DESC
  s.homepage         = "https://github.com/zonble/KKPurchaseManager/"
  # s.documentation_url = 'https://zonble.github.io/KKPurchaseManager/'
  s.author           = { "zonble" => "zonble@gmail.com" }
  s.source           = { :git => "https://github.com/zonble/KKPurchaseManager.git", :tag => s.version.to_s }

  s.platform         = :ios, :tvos, :osx
  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.9'
  s.tvos.deployment_target = '9.0'
  s.requires_arc     = true
  s.source_files     = 'Sources/KKPurchaseManager/*.swift'
  s.ios.frameworks   = 'UIKit'
  s.osx.frameworks   = 'AppKit'
  s.tvos.frameworks  = 'UIKit'
end

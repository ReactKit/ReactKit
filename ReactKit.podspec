Pod::Spec.new do |s|
  s.name     = 'ReactKit'
  s.version  = '0.7.1'
  s.license  = { :type => 'MIT' }
  s.homepage = 'https://github.com/ReactKit/ReactKit'
  s.authors  = { 'Yasuhiro Inami' => 'inamiy@gmail.com' }
  s.summary  = 'Swift Reactive Programming.'
  s.source   = { :git => 'https://github.com/inamiy/ReactKit.git', :tag => "#{s.version}" }
  s.source_files = 'ReactKit/**/*.{h,swift}'
  s.requires_arc = true

  s.osx.deployment_target = '10.9'
  s.osx.exclude_files = "ReactKit/UIKit"

  s.ios.deployment_target = '8.0'
  s.ios.exclude_files = "ReactKit/AppKit"

  s.dependency 'SwiftTask', '~> 2.6.3'
end

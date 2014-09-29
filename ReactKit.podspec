Pod::Spec.new do |s|
  s.name     = 'ReactKit'
  s.version  = '0.0.1'
  s.license  = { :type => 'MIT' }
  s.homepage = 'https://github.com/inamiy/ReactKit'
  s.authors  = { 'Yasuhiro Inami' => 'inamiy@gmail.com' }
  s.summary  = 'Swift Reactive Programming.'
  s.source   = { :git => 'https://github.com/inamiy/ReactKit.git', :tag => "#{s.version}" }
  s.source_files = 'ReactKit/**/*.{h,swift}'
  s.frameworks = 'Swift'
  s.requires_arc = true

  s.dependency 'SwiftTask', '~> 0.0.1'
  s.dependency 'SwiftState', '~> 0.0.1'
end

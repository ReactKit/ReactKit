Pod::Spec.new do |s|
  s.name     = 'ReactKit'
  s.version  = '0.4.0'
  s.license  = { :type => 'MIT' }
  s.homepage = 'https://github.com/ReactKit/ReactKit'
  s.authors  = { 'Yasuhiro Inami' => 'inamiy@gmail.com' }
  s.summary  = 'Swift Reactive Programming.'
  s.source   = { :git => 'https://github.com/inamiy/ReactKit.git', :tag => "#{s.version}" }
  s.source_files = 'ReactKit/**/*.{h,swift}'
  s.requires_arc = true

  s.dependency 'SwiftTask', '~> 2.4.0'
end

Pod::Spec.new do |s|
  s.name             = 'AdMobMentaAdapter'
  s.version          = '1.0.34'
  s.summary          = 'Menta mediation adapter for Google Mobile Ads (AdMob).'
  s.description      = 'Supports app open (splash), banner, interstitial, rewarded, and native.'
  s.homepage         = 'https://www.advlion.com'
  s.license          = { :type => 'MIT', :text => 'Copyright (c) Menta. All rights reserved.' }
  s.author           = { 'Menta' => 'mentasdk.vip@gmail.com' }

  s.ios.deployment_target = '12.0'
  s.requires_arc     = true
  s.static_framework = true

  s.source           = { :git => 'https://github.com/mentasdk/googleads-mobile-ios-mediation.git', :tag => s.version.to_s }
  # First pattern: local `:path => adapters/Menta`. Second: git clone of the repo root.
  s.source_files         = 'AdMobMentaAdapter/*.{h,m}', 'adapters/Menta/AdMobMentaAdapter/*.{h,m}'
  s.public_header_files  = 'AdMobMentaAdapter/*.h', 'adapters/Menta/AdMobMentaAdapter/*.h'
  s.swift_versions       = ['5.0']

  s.frameworks = 'Foundation', 'UIKit'

  s.dependency 'Google-Mobile-Ads-SDK', '>= 12.0'
  s.dependency 'MentaBaseGlobal',         '1.0.34'
  s.dependency 'MentaMediationGlobal',    '1.0.34'
  s.dependency 'MentaVlionGlobal',        '1.0.34'
  s.dependency 'MentaVlionGlobalAdapter', '1.0.34'

  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '-ObjC'
  }
end

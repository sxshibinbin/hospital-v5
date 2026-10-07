#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'ali_auth'
  s.version          = '1.3.9'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
  是一个集成阿里云号码认证服务SDK的flutter插件
                       DESC
  s.homepage         = 'http://ki5k.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'raohong07@163.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  s.dependency 'Flutter'
  s.dependency 'SDWebImage'
  s.dependency 'MJExtension'
  # s.dependency 'MBProgressHUD'

  s.frameworks = 'Network'

  # 2026-09-19: iOS SDK 升级 2.14.15 → 2.14.19（官方 numberAuthSDK_APP_iOS 包）。
  # 新框架放 libs-2.14.19/（保留 libs/ 旧框架，回退只需改回下面三行路径）
  s.vendored_frameworks = 'libs-2.14.19/ATAuthSDK.xcframework', 'libs-2.14.19/YTXMonitor.xcframework', 'libs-2.14.19/YTXOperators.xcframework'
  s.static_framework = false

  # 解决移动crash
  s.xcconfig = {
    'OTHER_LDFLAGS' => '-ObjC',
    'ENABLE_BITCODE' => 'NO'
  }
  
  # 加载静态资源
  s.resources = ['Assets/*']

  s.ios.deployment_target = '11.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
#   s.pod_target_xcconfig = {'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'   }
#   s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
end


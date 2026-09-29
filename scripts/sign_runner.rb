# 云端构建专用：给 Runner 的 Release 配置注入手动签名（App Store）
# 只改云端工作区的工程文件，不提交回仓库；本机工程不受影响。
require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |t|
  next unless t.name == 'Runner'
  t.build_configurations.each do |config|
    next unless config.name == 'Release'
    config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
    config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = 'hospital-v5 AppStore'
    config.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Distribution: Thirty Days Technology(shanxi) Co.,ltd (HDTYXYQC82)'
  end
end

project.save
puts 'Runner Release signing configured'

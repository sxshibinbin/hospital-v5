# iOS 18.6.2 真机安装 hospital-v5 Runbook（Xcode 14.2 本机适用）

## 背景

本机 macOS 12.7.6 上限 = Xcode 14.2，设备支持文件只到 iOS 16.x。
iOS 17 起苹果换了整套调试架构（CoreDevice + 联网拉取个性化镜像），必须 Xcode 15/16 + macOS 13.5/14.5+，
"拷贝 DeveloperDiskImage" 的老办法对 iOS 17+ 无效。给手机降级 iOS 也不可行（苹果已停止签名）。

**但 iOS 16.2 SDK 编出的包在 iOS 18 上正常运行** → 走"签名打包 + OTA 分发"路线。
打包/签名只跟苹果开发者门户 API 通信，全程不需要 Xcode 认识这台手机。

- 能做的：把 Release 包装上手机做功能测试（云后端 web.sstkjgf.com）。
- 不能做的：flutter run / 真机断点调试这台 iOS 18.6.2 手机（需另找 macOS 14.5+ 的 Mac 装 Xcode 16）。

## 第 0 步：确认开发者账号

钥匙串现有 3 个证书（`security find-identity -v -p codesigning`）：

| 团队 ID | 归属 | 备注 |
|---|---|---|
| HDTYXYQC82 | Thirty Days Technology(shanxi) Co.,ltd | 公司号，ExportOptions-adhoc.plist 默认用它 |
| GWJYG8BUFJ | Binbin Shi（个人） | 疑似免费个人号 |
| R2ZQF8A3K3 | 张建（个人） | 疑似免费个人号 |

判定付费账号：用该 Apple ID 登录 developer.apple.com，能看到 "Certificates, IDs & Profiles"
且 Devices 页可以手动加设备 = 付费；免费个人号没有这些页面。

- 有付费账号（公司号大概率是）→ 继续第 1~5 步，包 1 年有效。
- 全是免费号 → 免费号无法网页注册设备，只能：借一台装 Xcode 16 的 Mac 用数据线注册（描述文件 7 天有效，每周要重来），或续费 ¥688/年。

## 第 1 步：拿手机 UDID

最简单：手机 Safari 打开 https://www.pgyer.com/udid 按提示安装描述文件，页面直接显示 UDID。
（或用数据线连任意电脑的 Finder/iTunes 看标识符）

## 第 2 步：网页注册设备（浏览器即可，与本机无关）

developer.apple.com → Certificates, IDs & Profiles → Devices → [+]
→ 填入 UDID。注意每个会员年最多 100 台，删除不返还名额。

## 第 3 步：生成 Ad Hoc 描述文件

1. Identifiers 确认存在 `com.sstkjgf.app` 的 App ID（没有就新建，能力按工程现有勾）。
2. Profiles → [+] → Ad Hoc → 选 App ID → 选 HDTYXYQC82 名下开发证书 → 勾第 2 步的设备 → 下载 .mobileprovision。

## 第 4 步：本机打包（已备好脚本）

首次先做一次签名设置（二选一）：
- 甲（自动签名，推荐）：Xcode 打开 flutter_app/ios/Runner.xcworkspace → Runner → Signing & Capabilities → 勾掉 Automatically 前先选 Team = Thirty Days Technology(shanxi)，确认无红线。
- 乙（手动签名）：双击第 3 步的 .mobileprovision 导入 → Runner 改 Manual signing → 选该 profile。

然后：

```bash
cd ~/Desktop/workspace/hospital-v5/flutter_app
./build-ios-adhoc.sh          # 默认云后端；也可 ./build-ios-adhoc.sh http://xxx 内网地址
```

脚本自动注入阿里一键登录 SK（与 build-ios.sh 同源读本地密钥文件），产物：
`build/ios/ipa/*.ipa`，并拷贝到仓库根 `dist/IOS/`。

## 第 5 步：装到手机

- 方案 1（推荐，免数据线）：蒲公英 pgyer.com 上传 .ipa → 手机 Safari 打开短链 → 安装。
  若提示不受信任：设置 → 通用 → VPN与设备管理 → 信任对应证书。
- 方案 2：本机 Apple Configurator 2 或 Windows 爱思助手 USB 安装。

验证：手机打开 App，用老板测试号 13453100505 走云后端登录。

## 限制与后续

- 此路线只做"装包测试"；iOS 18.6.2 手机的断点调试需 macOS 14.5+ 的 Mac。
- 真机调试日常照旧用 iOS ≤16.2 测试机。
- 将来上架 App Store / TestFlight：必须 Xcode 16+ / iOS 18 SDK（2025-04 苹果新规），同样要换 Mac 或云构建（Codemagic 等）。

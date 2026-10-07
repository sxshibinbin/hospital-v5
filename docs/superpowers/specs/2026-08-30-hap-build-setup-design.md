# hospital-v5 Flutter App 鸿蒙 hap 打包能力补齐 — 设计

日期：2026-08-30
状态：待评审
适用工程：`flutter_app/`

## 1. 背景与目标

`flutter_app/` 内含一套完整的 HarmonyOS 工程脚手架（`ohos/`）。经核查：

- `ohos/build-profile.json5`：`runtimeOS: HarmonyOS`、`compatibleSdkVersion: 5.1.0(18)`、`targetSdkVersion: 6.1.0(23)`，产物为 `.hap`。
- `ohos/entry/src/main/ets/entryability/EntryAbility.ets` 引用 `@ohos/flutter_ohos`（华为 flutter fork 生成）。
- `.metadata` 的 `channel: "[user-branch]"`，证实该工程由华为 `flutter_flutter` fork 创建（原作者 Mac，`xiaoxutongxue`）。

但脚手架与当前机器脱节：

- 本机 `flutter` 为社区版 3.44.6（gitee 镜像，仅换源），**无 `hap` 构建目标、无 `enable-ohos`**。
- 本机未安装 DevEco Studio / HarmonyOS SDK / ohpm / hvigor。
- `pubspec.lock` 内 6 个原生插件（`webview_flutter`、`shared_preferences`、`image_picker`、`permission_handler`、`file_picker`、`ali_auth`）**均无 ohos 实现版本**。
- `ali_auth`（阿里云一键登录）插件 `pubspec` 只声明 `android`/`ios`，**无 ohos 实现**；其调用集中在 `lib/services/carrier_auth_service_mobile.dart`，且**不在 App 启动路径**。
- `build-profile.json5` 的签名证书路径指向他人 Mac（`/Users/xiaoxutongxue/.ohos/config/...`），本机无效。
- `ohos/entry/src/main/ets/` 下无 `GeneratedPluginRegistrant`（该文件由华为 flutter 工具在 build 时生成，属正常初始态）。

**目标**：在不影响现有 Android/桌面/Web 构建的前提下，让 `flutter_app` 能打出**可安装到鸿蒙真机、冷启动进入 App 首页不闪退**的调试 `.hap`。

**验收判据**：运行 `build-hap.bat` 成功产出签名 `.hap`，`hdc install` 到设备后 App 冷启动进入首页。

## 2. 现实约束与分工

`flutter build hap` 最终依赖鸿蒙 `hvigor` 打包与 DevEco 登录华为账号后自动生成的调试证书。**DevEco Studio 是带华为账号门槛的数 GB GUI 安装包**（捆绑 HarmonyOS SDK、ohpm、hvigor、node），无法脚本化安装，其调试签名也依赖登录态。

| 工作单元 | 负责 |
|---|---|
| W1 华为 flutter fork 克隆与版本锁定 | 我（shell） |
| W2 DevEco Studio + HarmonyOS SDK 安装、华为账号登录 | **你（GUI+账号）** |
| W3 工程接线（pub get 生成 ohos 插件注册、ohpm 解析 har） | 我 |
| W4 原生插件升级到含 ohos 实现的版本 | 我 |
| W5 ali_auth 鸿蒙降级（条件导入兜底，不实现真实逻辑） | 我 |
| W6 清理无效签名配置 + 本机调试签名 | 我配置 + 你登录态 |
| W7 编写 `build-hap.bat` | 我 |

## 3. 工作单元设计

### W1 华为 flutter fork（独立目录共存）
- 克隆 `https://gitee.com/openharmony-sig/flutter_flutter.git`（或对齐版本的华为维护 fork）到 `D:\flutter_ohos`。
- **不覆盖**全局 `/d/flutter`（社区 3.44.6），仅打 hap 时用 `D:\flutter_ohos\bin\flutter` 绝对路径，保护 CLAUDE.md 中 `flutter build apk` 等既有流程。
- `git checkout` 到与 `compatibleSdkVersion 5.1.0(18)` 匹配的版本（见 §4 风险）。
- 配置镜像 env：`PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`（ohpm 用 `https://ohpm.openharmony.cn/ohpm/`）。

### W2 DevEco + HarmonyOS SDK（你）
- 从华为开发者站下载安装 DevEco Studio（选含 API 18 / 5.1.0 Release 的 SDK 组件）。
- 首次启动登录华为账号；SDK Manager 安装 HarmonyOS 5.1.0(18) 与 6.1.0(23) 相关组件，确保 `ohpm`、`hvigorw` 可用。
- D 盘剩 ~50G，装前清理一次。

### W3 工程接线
- 在 `D:\flutter_ohos\bin\flutter` 下 `flutter pub get`。
- 验证生成 `ohos/entry/src/main/ets/plugins/GeneratedPluginRegistrant.ets`，且 `EntryAbility` 引用可解析。
- `ohpm install` 解析 `@ohos/flutter_ohos` har。

### W4 原生插件适配
将以下依赖升到各自含 ohos 实现的最低版本（对齐华为/社区 ohos 插件兼容表）：
`webview_flutter`、`shared_preferences`、`image_picker`、`permission_handler`、`file_picker`。
纯 Dart 依赖（`provider`、`dio`、`http`、`go_router`、`fl_chart`、`flutter_markdown`、`genui`、`json_schema_builder`）不动。
若某插件无 ohos 版本，则其功能在鸿蒙端按 W5 同法降级，不阻塞打包。

### W5 ali_auth 鸿蒙降级
- `carrier_auth_service_mobile.dart` 沿用现有条件导入风格，新增 ohos 兜底变体（no-op / 抛可控异常），使一键登录入口在鸿蒙端不崩溃、短信登录照常。
- 本次**不实现** ali_auth 的 ohos 真实逻辑（决策：登录后续再议）。

### W6 签名
- 移除 `build-profile.json5` 中他人 Mac 的证书绝对路径与密文，置空 `signingConfigs` 或改为本机占位。
- 由 DevEco 登录后自动生成调试签名，或 `hvigorw` 命令行调试签名，`buildMode: debug`。

### W7 构建脚本
`flutter_app/build-hap.bat`：设 `FLUTTER_HOME=D:\flutter_ohos` 并以该 flutter 绝对路径执行 `flutter build hap --debug`，成功后提示产物路径（`ohos/entry/build/default/outputs/default/`）。

## 4. 风险与缓解

| 风险 | 说明 | 缓解 |
|---|---|---|
| 版本三方不匹配（头号） | fork flutter 版本 ↔ `@ohos/flutter_ohos` har ↔ DevEco HarmonyOS SDK(API) 必须对齐 | W1+W2 完成后先跑**最小 ohos 冒烟 build**验证链路，再灌 W4 业务插件 |
| 插件无 ohos 版 | 个别插件华为兼容表无 ohos 实现 | 该功能鸿蒙端条件导入降级，不阻塞 hap 产出 |
| ali_auth 无 ohos SDK | 阿里云 Dypns 无鸿蒙 SDK | 本次降级跳过，登录后续再议 |
| 磁盘 | 50G 偏紧，全套约 15–20G | W2 前清理；DevEco/SDK 装 D 盘独立目录 |
| 首次构建报错混杂 | 工具链/版本/插件问题叠在一起难归因 | 方案 1：先冒烟后逐个插件回归 |

## 5. 构建与验证流程
1. 冒烟：最小 ohos build 跑通链路（工具链+签名）。
2. 逐个回归：每接入一类插件即 `flutter build hap` 一次，失败可归因。
3. 全量：W4 完成后产出完整签名 hap。
4. 装机：`hdc install`，真机/模拟器冷启动验证进入首页不闪退。

## 6. 边界（明确不改动）
- 不覆盖全局 `flutter`，Android/apk/web/桌面构建链保持原样。
- 不改后端 / 前端 / 管理端。
- 不改业务逻辑，仅就 ohos 对 ali_auth 入口做降级兜底。

## 7. 提交与分支
- 新增脚本、`build-profile.json5`、`pubspec.yaml` 改动提交到 `develop` 分支（本仓 develop 已建）。
- `D:\flutter_ohos`、SDK、签名证书属本机环境，**不纳入 git**（确认 `.gitignore` 覆盖 ohos 构建产物）。

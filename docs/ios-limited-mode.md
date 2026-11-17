# iOS 临时展示限制开关说明

## 用途与当前配置

为配合当前 iOS 上架调整，在同一套 Flutter 代码中，仅对 iOS 启用临时展示限制。安卓、鸿蒙保持原有展示。待相关设备资质齐全后，可关闭开关并重新发布 iOS。

配置文件：[`flutter_app/lib/config/app_config.dart`](../flutter_app/lib/config/app_config.dart)

```dart
static const bool iosLimitedModeEnabled = true;
```

正式包的生效条件为：

```dart
Platform.isIOS && iosLimitedModeEnabled
```

| 运行平台 | 开关为 true | 开关为 false |
| --- | --- | --- |
| iOS 真机、iOS 模拟器 | 启用临时限制 | 恢复原有展示 |
| 安卓 | 保持原有展示 | 保持原有展示 |
| 鸿蒙 | 保持原有展示 | 保持原有展示 |

按原有流程打包即可，无需新增打包参数或配置文件。开关随代码进入安装包，不是远程配置；修改后必须重新构建、分发或发布，已安装的旧包不会自动改变。

## 当前限制范围

- 监测首页隐藏血压、血氧饱和度、体温卡片，保留心率与步数；相关指标详情路由回到监测页面。
- 指标详情隐藏健康判断“状态”行，取消健康参考区间背景，数值着色与主要趋势线使用统一颜色；保留数据、单位、时间与趋势。
- 消息列表过滤涉及上述隐藏指标的记录，以及包含偏高、偏低、心率异常、呼吸异常等判断文案的记录。具体匹配词见 `hidesMetric` 和 `hidesMessage`。
- 设备监测页面的固定文案和动态消息文案通过 `DeviceMessageText` 转换：“报警／警告／告警／预警”显示为“消息”，“接警人员”显示为“接收人员”。
- 消息详情隐藏报警等级、事件等级，并调整相关状态展示颜色。
- 设备设置隐藏体温等敏感指标参数，以及名称包含“异常”的开关和输入项，包括心率、呼吸异常阈值配置。

这些调整作用于客户端展示及入口；后端接口、设备协议、原始记录不变。该开关不代表停止设备采集或服务端存储。

## 后续恢复步骤

1. 在 `app_config.dart` 中将 `iosLimitedModeEnabled` 从 `true` 改为 `false`。
2. 运行静态分析与对应自动测试，核对恢复后的指标、详情、设备设置、消息文案和健康判断展示。
3. 在 Mac 上按现有流程构建 iOS，真机验证后更新上架截图、应用说明等材料，并提交新版本。
4. 确认安卓、鸿蒙继续保留原有展示。

若只是调整临时限制范围，修改相关页面的 `AppConfig.iosLimitedMode` 条件，以及配置文件中的匹配词和文案转换即可。

限制适用于该版本的所有 iOS 用户，不根据审核账号或审核状态切换；恢复通过后续版本发布完成。

## 代码位置与验证

| 文件 | 职责 |
| --- | --- |
| `flutter_app/lib/config/app_config.dart` | 统一开关、过滤规则、消息展示转换 |
| `flutter_app/lib/router/app_router.dart` | 隐藏指标详情的入口保护 |
| `flutter_app/lib/screens/health_monitoring/health_monitoring_screen.dart` | 指标卡片、健康区间、设备状态展示 |
| `flutter_app/lib/screens/health_monitoring/metric_detail_screen.dart` | 指标详情状态与趋势图展示 |
| `flutter_app/lib/screens/health_monitoring/alarm_record_screen.dart` | 消息过滤、文案、详情等级 |
| `flutter_app/lib/screens/health_monitoring/device_detail_screen.dart` | 设备参数和异常阈值设置 |
| `flutter_app/test/ios_limited_mode_test.dart` | 限制开启、关闭及消息展示测试 |

在 `flutter_app` 目录下执行：

```sh
flutter analyze lib/config/app_config.dart lib/router/app_router.dart lib/screens/health_monitoring test/ios_limited_mode_test.dart
flutter test --no-pub test/ios_limited_mode_test.dart
```

`debugLimitedModeOverride` 仅供自动测试模拟限制开启或关闭，通过 `assert` 生效，正式 Release 包仍使用实际操作系统和统一开关判断。

首次实现时静态分析与 3 项自动测试通过；Windows 环境尚未完成 iOS 打包、真机验证和安卓、鸿蒙真机回归。发布前需验证首页、详情入口、历史消息、设备设置，以及其他两端的原有功能。此展示调整不保证审核通过。

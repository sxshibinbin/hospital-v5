# 鸿蒙原生 HAP 打包说明（给 AI 执行）

## 任务目标

为 `hospital-v5` 打包一个 **HarmonyOS ARM64 调试 HAP**，并把后端地址编译为：

```text
https://web.sstkjgf.com
```

不要把 `ohos-x64` 用于华为真机；`ohos-x64` 只用于电脑模拟器。

## 直接执行的命令

以下命令必须在项目根目录执行：`D:\WorkSpace\WorkSpace_\hospital-v5`。

### CMD

```bat
cd /d D:\WorkSpace\WorkSpace_\hospital-v5
build-hap.bat debugger ohos-arm64 https://web.sstkjgf.com
```

### PowerShell

```powershell
Set-Location 'D:\WorkSpace\WorkSpace_\hospital-v5'
.\build-hap.bat debugger ohos-arm64 https://web.sstkjgf.com
```

参数含义：

| 参数 | 必须值 | 含义 |
| --- | --- | --- |
| 第 1 个参数 | `debugger` | 调试构建，等价于 Flutter `--debug` |
| 第 2 个参数 | `ohos-arm64` | ARM64 真机架构 |
| 第 3 个参数 | `https://web.sstkjgf.com` | 编译时注入的后端地址 |

脚本实际执行的 Flutter 参数包含：

```text
flutter build hap --debug --target-platform ohos-arm64 --dart-define=API_BASE_URL=https://web.sstkjgf.com --no-pub --no-codesign
```

## 输出文件

成功后查看：

```text
D:\WorkSpace\WorkSpace_\hospital-v5\dist\harmonyos\sstkjgf-1.0.0-1-debugger-arm64.hap
```

脚本会自动完成两件事：

1. 使用 debug 签名材料对 unsigned HAP 签名。
2. 使用 `hap-sign-tool verify-app` 校验签名，并检查 `libs/arm64-v8a/libflutter.so`。

## 真机安装前提

调试 HAP 必须使用已绑定目标手机 UDID 的 debug Profile。否则即使打包成功，执行 `hdc install` 也可能出现 `9568257` 或 `fail to verify pkcs7 file`。

满足以下条件后，才可以安装：

```bat
hdc install -r D:\WorkSpace\WorkSpace_\hospital-v5\dist\harmonyos\sstkjgf-1.0.0-1-debugger-arm64.hap
```

如果只是上传 AppGallery Connect 或做正式分发，不要使用本节的调试命令；应使用 release 签名命令。

## 调试签名材料位置

脚本默认从以下位置读取 debug 签名材料：

```text
flutter_app\ohos\signing\com.sstkjgf.app.hm.p12
flutter_app\ohos\signing\com.sstkjgf.app.hm.debug.cer
flutter_app\ohos\signing\com.sstkjgf.app.hm.debugDebug.p7b
```

也会读取：

```text
flutter_app\ohos\build-profile.json5
```

签名材料和密码属于敏感信息，不要提交到代码仓库，也不要在回答中输出密码。

## 工具链

脚本默认使用：

```text
Flutter OHOS SDK: D:\tmp\flutter_ohos_3_44
DevEco Studio:    D:\Program Files\Huawei\DevEco Studio
```

如果 Flutter OHOS SDK 不在默认位置，在执行打包命令前设置：

```bat
set "FLUTTER_OHOS=D:\实际的\flutter_ohos_sdk路径"
```

## Flutter 权限问题处理

如果 Flutter 报告无法写入 `.flutter_tool_state` 或 SDK `bin\cache\lockfile`，先把 Flutter 状态目录指向项目内可写目录，再重试打包：

```powershell
Set-Location 'D:\WorkSpace\WorkSpace_\hospital-v5'
$env:APPDATA = Join-Path (Get-Location) '.dart-appdata'
$env:LOCALAPPDATA = Join-Path (Get-Location) '.dart-localappdata'
.\build-hap.bat debugger ohos-arm64 https://web.sstkjgf.com
```

只有出现上述权限错误时才需要设置这两个环境变量。

## 结果检查命令

```bat
tar -tf dist\harmonyos\sstkjgf-1.0.0-1-debugger-arm64.hap | findstr /I "libs/arm64-v8a"
```

至少应看到：

```text
libs/arm64-v8a/libflutter.so
```

如果输出的是 `libs/x86_64`，说明打成了模拟器包，必须重新执行：

```bat
build-hap.bat debugger ohos-arm64 https://web.sstkjgf.com
```

## 其他模式（不要混用）

以下命令是同一项目支持的其他场景：

```bat
REM ARM64 调试包的简写，等价于 debugger + ohos-arm64
build-hap.bat device https://web.sstkjgf.com

REM ARM64 release 编译、debug 签名，适合真机性能自测
build-hap.bat device-release https://web.sstkjgf.com

REM ARM64 release 签名包，用于 AGC 上传/分发
build-hap.bat release ohos-arm64 https://web.sstkjgf.com

REM x64 模拟器调试包，不要安装到 ARM64 真机
build-hap.bat simulator https://web.sstkjgf.com
```

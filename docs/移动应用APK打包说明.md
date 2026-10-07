# 移动应用 APK 打包说明

本文记录本项目本次成功打包 Android APK 的方式，适用于华为 HarmonyOS 4.2 手机按 Android APK 方式安装测试。

## 打包结论

- 移动端工程路径：`D:\WorkSpace\WorkSpace_\hospital-v5\flutter_app`
- Android 工程路径：`D:\WorkSpace\WorkSpace_\hospital-v5\flutter_app\android`
- APK 输出路径：`D:\WorkSpace\WorkSpace_\hospital-v5\dist\hospital-v5-harmonyos-4.2-debug.apk`
- 构建类型：`debug`
- 应用名：`安小记`
- 包名：`com.example.flutter_app`
- 本次手机真机调试后端地址：`http://172.19.51.96:8000`
- `minSdkVersion=24`
- `targetSdkVersion=36`

## 本次环境准备

Flutter SDK 使用本机路径：

```powershell
D:\flutter
```

项目内安装了 Android SDK，避免占用 C 盘：

```powershell
D:\WorkSpace\WorkSpace_\hospital-v5\flutter_app\.android-sdk
```

Android SDK 安装组件：

- `platform-tools`
- `platforms;android-36`
- `build-tools;36.0.0`
- `ndk;28.2.13676358`

JDK 使用：

```powershell
C:\Program Files\Java\jdk-17.0.12
```

## 本次配置调整

`flutter_app\android\local.properties` 中增加/确认：

```properties
flutter.sdk=D:\\flutter
sdk.dir=D:\\WorkSpace\\WorkSpace_\\hospital-v5\\flutter_app\\.android-sdk
flutter.buildMode=debug
flutter.versionName=1.0.0
flutter.versionCode=1
```

`flutter_app\android\gradle.properties` 中增加：

```properties
kotlin.incremental=false
kotlin.compiler.execution.strategy=in-process
org.gradle.workers.max=4
```

原因：本机依赖缓存存在 C 盘和 D 盘跨盘路径，Kotlin 增量编译会出现卡住或缓存异常，关闭增量编译后构建稳定。

`flutter_app\android\settings.gradle.kts` 和 `flutter_app\android\build.gradle.kts` 中增加国内 Maven 镜像：

```kotlin
maven { url = uri("https://maven.aliyun.com/repository/google") }
maven { url = uri("https://maven.aliyun.com/repository/central") }
maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
```

构建时增加 Flutter engine 国内镜像：

```powershell
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
```

原因：默认 `https://storage.googleapis.com` 下载 Flutter engine 依赖时会卡住，切换镜像后构建成功。

真机安装测试时必须指定后端地址，不能使用默认 `http://localhost:8000`。手机上的 `localhost` 指的是手机本机，不是运行后端的电脑。

本次电脑 WLAN IPv4 为：

```powershell
172.19.51.96
```

所以本次 APK 使用的接口地址为：

```powershell
http://172.19.51.96:8000
```

如果电脑 IP 变化，需要重新获取 IPv4，并重新打包。

## 推荐一键打包

项目根目录已提供 Windows 批处理脚本：

```powershell
D:\WorkSpace\WorkSpace_\hospital-v5\build-apk.bat
```

在项目根目录直接执行：

```powershell
.\build-apk.bat
```

脚本会自动完成：

- 自动获取本机 IPv4，并生成 `API_BASE_URL=http://本机IP:8000`
- 自动生成 Flutter Gradle 所需的 `dart-defines`
- 固定使用 D 盘项目内 Android SDK 和 Gradle 缓存
- 执行 `:app:assembleDebug`
- 复制 APK 到 `D:\WorkSpace\WorkSpace_\hospital-v5\dist\hospital-v5-harmonyos-4.2-debug.apk`
- 校验 APK 签名、包信息和 SHA256

如果自动识别的 IP 不正确，可以手动指定：

```powershell
.\build-apk.bat 172.19.51.96
```

如果端口不是 `8000`：

```powershell
.\build-apk.bat 172.19.51.96 8000
```

也可以直接传完整后端地址：

```powershell
.\build-apk.bat http://172.19.51.96:8000
```

后续真机测试推荐优先使用这个脚本打包。

## 构建命令

在项目根目录执行：

```powershell
cd D:\WorkSpace\WorkSpace_\hospital-v5

$env:APPDATA='D:\WorkSpace\WorkSpace_\hospital-v5\.dart_cli_home'
$env:LOCALAPPDATA='D:\WorkSpace\WorkSpace_\hospital-v5\.dart_cli_home'
$env:GRADLE_USER_HOME='D:\WorkSpace\WorkSpace_\hospital-v5\flutter_app\.gradle_home'
$env:ANDROID_HOME='D:\WorkSpace\WorkSpace_\hospital-v5\flutter_app\.android-sdk'
$env:ANDROID_SDK_ROOT='D:\WorkSpace\WorkSpace_\hospital-v5\flutter_app\.android-sdk'
$env:JAVA_HOME='C:\Program Files\Java\jdk-17.0.12'
$env:FLUTTER_SUPPRESS_ANALYTICS='true'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'

cd D:\WorkSpace\WorkSpace_\hospital-v5\flutter_app\android
.\gradlew.bat assembleDebug `
  -Pdart-defines=QVBJX0JBU0VfVVJMPWh0dHA6Ly8xNzIuMTkuNTEuOTY6ODAwMA== `
  --stacktrace `
  --no-daemon `
  --console=plain
```

其中 `-Pdart-defines` 是 `API_BASE_URL=http://172.19.51.96:8000` 的 Base64 编码。重新更换后端地址时，可用下面命令生成新的值：

```powershell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('API_BASE_URL=http://你的电脑IP:8000'))
```

Flutter 默认 APK 产物：

```powershell
D:\WorkSpace\WorkSpace_\hospital-v5\flutter_app\build\app\outputs\flutter-apk\app-debug.apk
```

本次复制后的安装包：

```powershell
D:\WorkSpace\WorkSpace_\hospital-v5\dist\hospital-v5-harmonyos-4.2-debug.apk
```

复制命令：

```powershell
New-Item -ItemType Directory -Force -Path D:\WorkSpace\WorkSpace_\hospital-v5\dist
Copy-Item `
  -LiteralPath D:\WorkSpace\WorkSpace_\hospital-v5\flutter_app\build\app\outputs\flutter-apk\app-debug.apk `
  -Destination D:\WorkSpace\WorkSpace_\hospital-v5\dist\hospital-v5-harmonyos-4.2-debug.apk `
  -Force
```

## 校验命令

校验 APK 签名：

```powershell
D:\WorkSpace\WorkSpace_\hospital-v5\flutter_app\.android-sdk\build-tools\36.0.0\apksigner.bat verify --verbose --print-certs D:\WorkSpace\WorkSpace_\hospital-v5\dist\hospital-v5-harmonyos-4.2-debug.apk
```

本次结果：

- 签名校验通过
- APK Signature Scheme v2：`true`
- 签名证书：`Android Debug`

查看 APK 基本信息：

```powershell
D:\WorkSpace\WorkSpace_\hospital-v5\flutter_app\.android-sdk\build-tools\36.0.0\aapt.exe dump badging D:\WorkSpace\WorkSpace_\hospital-v5\dist\hospital-v5-harmonyos-4.2-debug.apk
```

本次关键结果：

- `package name='com.example.flutter_app'`
- `versionCode='1'`
- `versionName='1.0.0'`
- `sdkVersion:'24'`
- `targetSdkVersion:'36'`
- `application-label:'安小记'`

查看 SHA256：

```powershell
Get-FileHash -LiteralPath D:\WorkSpace\WorkSpace_\hospital-v5\dist\hospital-v5-harmonyos-4.2-debug.apk -Algorithm SHA256
```

本次 SHA256：

```text
5FFBD58C739E87481DE58B5C18D996581C50C00610A8E891FBE552760EFC34A6
```

## 注意事项

- 本次产物是 debug 包，可以用于华为 HarmonyOS 4.2 手机安装测试。
- 手机需要允许安装未知来源应用。
- 正式发布应用市场时，需要配置正式签名文件并打 release 包。
- 若重新构建时长时间停在下载依赖，优先确认 Maven 镜像和 `FLUTTER_STORAGE_BASE_URL` 是否生效。

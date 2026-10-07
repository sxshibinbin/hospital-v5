# 鸿蒙 hap 打包环境搭建（工具链安装步骤）

> 这部分需要你使用自己的华为账号，在 GUI 环境中完成。

## 1. 安装 DevEco Studio

1. 前往 [华为开发者官网](https://developer.huawei.com/consumer/cn/deveco-studio/) 下载 DevEco Studio 最新版。
2. 运行安装包，安装到 `D:\Huawei\DevEco Studio`（**不要用 C 盘**，你 D 盘空间更大）。
3. 安装完成后启动 DevEco Studio，**使用华为账号登录**（登录才能生成调试签名证书）。
4. 首次启动会自动弹出 SDK Manager 配置界面，选择组件：
   - **HarmonyOS SDK 5.1.0(18)**（必选，对应 `compatibleSdkVersion`）
   - **HarmonyOS SDK 6.1.0(23)**（可选，匹配 `targetSdkVersion`）

## 2. 验证安装

打开命令行，确认以下命令可以找到：

```bash
ohpm -v
hvigorw --version
hdc -V
```

如果 `ohpm` 或 `hvigorw` 不在 PATH 中，手动添加：
- `D:\Huawei\DevEco Studio\tools\ohpm\bin`
- `D:\Huawei\DevEco Studio\tools\hvigor\bin`

## 3. 首次打开项目生成调试证书

1. 在 DevEco Studio 中 **File → Open**，选择 `D:\WorkSpace\WorkSpace_\hospital-v5\flutter_app\ohos` 目录。
2. DevEco 会自动检测缺少的配置并提示「自动生成调试证书」，点击 **Sign In**确认登录后生成。
3. 生成成功后，`build-profile.json5` 中的 `signingConfigs` 会被自动填充为你的本机调试证书路径。
4. **关闭 DevEco**（后续我们用 CLI 构建，不需要 IDE 一直开着）。

## 4. 检查 SDK 与签名

```bash
# 查看可用 SDK 版本
hdc list targets
# 查看签名配置（应该自动生成了你的证书路径）
cat flutter_app/ohos/build-profile.json5
```

## 5. 生成调试签名证书时可能遇到的问题

- **未登录**：DevEco → 右上角头像 → 登录华为账号。
- **SDK 未安装**：DevEco → Settings → SDK Manager → 勾选 5.1.0(18) 并安装。
- **hdc 找不到设备**：确保手机开启「开发者模式」并连接 USB，或在 DevEco 中运行模拟器。

## 6. 完成后的验证

回到项目目录，运行：

```bash
cd D:\WorkSpace\WorkSpace_\hospital-v5\flutter_app
D:\flutter_ohos\bin\flutter build hap --debug
```

应该能正常构建产出 `.hap` 文件。
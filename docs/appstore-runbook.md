# App Store 上架流水线 Runbook（本机 Xcode 14.2 打不了上架包，走 GitHub 云构建）

**原理**：本机只负责"备料"（签名文件、配置、镜像推送）；真正的构建在 GitHub 的 macOS 云机器上
（Xcode 16+，满足苹果 2025-04 起的 SDK 硬性要求），构建出的 IPA 自动上传 App Store Connect。

**已备好的东西**（不用动）：
- `~/appstore-signing/appstore_dist.csr` — 证书申请文件（上传门户用）
- `~/appstore-signing/appstore_dist_key.pem` — 证书私钥（绝密，别动别传）
- `flutter_app/ios/ExportOptions-appstore.plist` — App Store 导出配置（manual 签名）
- `.github/workflows/ios-appstore.yml` — 云构建流水线（手动触发）

---

## 阶段 A：苹果门户办两样东西（浏览器，约 10 分钟）

### A1. 创建 App Store 发行证书（classic 版，不是 Managed！）
1. 打开 https://developer.apple.com/account/resources/certificates/add
2. 类型选 **Apple Distribution**（在 Distribution 分组下，**不带 Managed 字样**）
3. 上传 CSR：文件选 `~/appstore-signing/appstore_dist.csr`
4. 创建后点 **Download** 下载 `appstore_dist.cer`，放到 `~/appstore-signing/` 目录
   （然后叫我一声，我把它打成 .p12 交给云构建用）

### A2. 创建 App Store 描述文件
1. 打开 https://developer.apple.com/account/resources/profiles/add
2. 类型 **App Store**（Distribution 分组下）
3. App ID 选 **com.sstkjgf.app**
4. 证书选刚创建的 Apple Distribution
5. **描述文件名称必须填：`hospital-v5 AppStore`**（云构建配置里预填了这个名字，不一致会构建失败）
6. 下载 `.mobileprovision`，也放到 `~/appstore-signing/`

## 阶段 B：GitHub 镜像仓库（约 10 分钟）

1. GitHub 账号（有就跳过）：https://github.com/signup 注册
2. 新建**私有**空仓库（名字随意，如 hospital-v5，不要勾 README）：
   https://github.com/new → 选 Private
3. 生成访问令牌 PAT：https://github.com/settings/tokens → Generate new token (classic)
   → 勾 **repo** 权限 → 生成后复制保存（只显示一次）
4. 到 Gitea 配自动镜像（一次配置，以后 push 自动同步）：
   http://120.26.226.134:3000 → qsg/hospital-v5 → 设置 → 推送镜像 → 添加推送镜像
   - Git 远程仓库地址：`https://github.com/<你的GitHub用户名>/hospital-v5.git`
   - 授权：用户名 = GitHub 用户名，密码 = 刚才的 PAT
   - 频率默认 8 小时，可点"立即同步"

## 阶段 C：App Store Connect 两张通行证（约 5 分钟）

1. API 密钥（云构建上传包用）：
   https://appstoreconnect.apple.com/access/integrations/api/subs
   → 生成 API 密钥，角色选 **App Manager** → 记下 **Issuer ID** 和 **Key ID**，
   点下载 `AuthKey_XXX.p8`
   （注意：.p8 只能下载一次，别丢）
2. 顺手确认公司号能登 App Store Connect：https://appstoreconnect.apple.com
   （用 18234039992@163.com 登录）

## 阶段 D：创建 App 记录（约 15 分钟，可晚点做）

1. https://appstoreconnect.apple.com/apps → 左上 [+] → **新建 App**
   - 名称：三十天时刻智护（如重名需另想）
   - 主要语言：简体中文
   - Bundle ID：com.sstkjgf.app
   - SKU：sstkjgf-001
2. App 信息页两个必填项（提交审核前备好即可）：
   - **隐私政策 URL**：需要一个公网可访问的隐私政策网页（你们 H5 站加一个页面即可）
   - **ICP 备案号**：中国大陆区上架强制要求，填 sstkjgf.com 域名的备案号（如"晋ICP备XXXXXXXX号"）
3. 版本页素材（提审前备好）：
   - 截图：6.9 英寸 iPhone 至少 1 张（**我可以帮你用模拟器批量生成**，叫我）
   - App 描述、关键词、年龄分级问卷
4. 医疗类提示：AI 问诊类目审核较严，准备一段"AI 输出不构成医疗建议"的免责说明，
   审核员可能会在备注里要求补充医疗资质材料

## 阶段 E：配 Secrets + 跑流水线（我做，你授权即可）

A1/A2 的两个文件放好后，把下面信息给我，剩下我全配：
1. GitHub PAT（阶段 B3 生成的）
2. ASC 的 Issuer ID、Key ID 和 AuthKey_XXX.p8 文件（阶段 C1 下载的）

我会完成：.cer→.p12 打包、全部 6 个 GitHub Secrets 写入、
推送 workflow 到 GitHub、手动触发构建、盯到 IPA 上传进 App Store Connect，
然后你在 ASC 版本页点"**提交以供审核**"就完事。

> 不想把令牌给我的话：Secrets 也可以自己在 GitHub 仓库页 Settings → Secrets and variables →
> Actions 里逐个添加（名称见 `.github/workflows/ios-appstore.yml` 里的 secrets 引用），构建你自己点触发。

---

## Secrets 清单（共 6 个，阶段 E 用）

| 名称 | 内容 | 来源 |
|---|---|---|
| APPSTORE_DIST_P12 | p12 文件 base64 | 我用 A1 的 .cer + 本机私钥打包 |
| P12_PASSWORD | p12 密码 | 我生成 |
| APPSTORE_MOBILEPROVISION | profile 文件 base64 | A2 下载的 .mobileprovision |
| ALIYUN_NUMBER_AUTH_IOS_SK | 一键登录 SK | 本地 flutter_app/android/aliyun-number-auth.local.properties |
| ASC_KEY_ID / ASC_ISSUER_ID | API 密钥两个 ID | 阶段 C1 |
| ASC_PRIVATE_KEY_P8 | .p8 文件内容 | 阶段 C1 下载 |

## 长期发版流程（一次搭好，以后就这样发）

1. 代码提交进 Gitea main → 等 8 小时自动镜像（或手动点同步）
2. GitHub 仓库 Actions 页 → 选 "iOS App Store 构建上传" → Run workflow
3. 约 20 分钟后包自动进 App Store Connect → 版本页提交审核
4. 审核通过后 ASC 上点"发布"（或选自动发布）

## 备注

- 云端 Flutter 固定 3.38.10（与本机一致，Dart ^3.10.0 兼容已验证）
- 免费额度：GitHub 私有仓库 macOS 构建按 10 倍计费，2000 分钟/月 ≈ 每月 6~8 次构建；
  不够用的话换 Codemagic（500 min/月不打折，需要注册新账号），流水线改法类似
- 苹果废弃 altool 上传功能时（日志报 altool 不可用），workflow 最后一步换 fastlane pilot，
  到时叫我改

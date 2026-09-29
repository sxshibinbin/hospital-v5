# GitHub CI 专用仓库（hospital-v5 App Store 构建启动器）

这个仓库**只存放构建配置**（.github/workflows/），业务代码不在这里。

构建时由 GitHub Actions 的 macOS 云机器直接从公司 Gitea 拉取最新代码：
http://120.26.226.134:3000/qsg/hospital-v5（凭证走 GitHub Secret: GITEA_TOKEN）

为什么这样设计：
- Gitea 历史里有大文件（247MB 安装包）和密钥（backend/.env），无法推到 GitHub
- 业务代码以 Gitea 为准，本仓库不需要同步

修改构建流程 → 编辑 .github/workflows/ios-appstore.yml → commit & push →
在 GitHub Actions 页面手动触发（Run workflow）。

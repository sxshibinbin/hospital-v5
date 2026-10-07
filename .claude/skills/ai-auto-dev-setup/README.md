# ai-auto-dev-setup - AI事业部全流程自动化研发安装工具

一键安装 AI 事业部多 Agent 编排体系的全部技能。

## 快速开始

### 一键安装全流程研发技能

在 Claude Code 中输入：

```
安装全自动化研发流程
```

或：

```
一键安装研发技能
```

AI 会引导您完成安装流程，包括选择安装位置、配置 TFS 权限等。

## 功能特性

| 功能 | 说明 |
|------|------|
| 一键安装 | 安装 11 个研发流程技能 |
| 单独安装 | 按需安装特定技能 |
| 全局/项目级 | 支持两种安装位置 |
| TFS 配置 | 自动配置 ai-tfs-integration 权限 |

## 技能清单

安装全流程后，您将获得以下技能：

| 技能名称 | 功能说明 |
|----------|----------|
| ai-auto-dev | 主调度技能 - 多需求并行自动开发 |
| ai-tfs-integration | TFS 集成 - 工作项管理、代码提交检查 |
| ai-prd-auto | 需求分析 - 将需求转化为结构化 PRD |
| ai-architecture-design | 架构设计 - 生成系统架构、数据库模型 |
| ai-backend-dev-pro | 后端开发 - Java Spring Boot / AKSO 开发 |
| ai-frontend-dev-pro | 前端开发 - Vue.js 前端编码 |
| ai-code-review-agent | 代码审查 - 多技术栈代码审查 |
| ai-automated-test-agent | 自动化测试 - 多类型测试用例生成 |
| ai-git-merge | 合并分支 - Git 分支合并工作流 |
| ai-git-push | 代码提交 - 代码提交推送工作流 |
| ai-project-knowledge | 知识库生成 - 自动生成项目知识库 |

## 安装位置

### 全局安装（推荐）

- 路径：`~/.claude/skills/`
- 所有项目可用
- 适合日常开发环境

### 项目级安装

- 路径：`<项目根目录>/.claude/skills/`
- 仅本项目可用
- 适合特定项目的定制配置

## 使用方式

### 一键全安装

```
用户: 安装全自动化研发流程

AI 执行:
1. 询问安装位置 → 用户选择"全局安装"
2. 更新缓存 → 成功
3. 执行批量安装...
   [OK] ai-auto-dev 已安装
   [OK] ai-prd-auto 已安装
   ...
4. 配置 TFS 权限 → 询问 PAT 和 Collection
5. 安装完成

安装完成！已安装 11 个技能。
```

### 单独安装技能

```
用户: 安装 ai-tfs-integration

AI 执行:
1. 更新缓存 → 成功
2. 从 TFS 仓库克隆技能 → 创建符号链接
   [OK] ai-tfs-integration 已安装
3. 配置 TFS 权限 → 询问 PAT 和 Collection
4. 安装完成
```

### 查看可用技能

```
用户: 查看清单

AI 执行:
列出可用工作流程和技能列表
```

## 命令行参考

本技能提供脚本支持命令行操作：

```bash
# 显示帮助
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --help

# 一键安装全流程（全局）
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --workflow ai-auto-dev --location global

# 一键安装全流程（项目级）
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --workflow ai-auto-dev --location project

# 单独安装技能
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --skill <技能名> --location global

# 列出可用技能
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --list

# 查看工作流程
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --list-workflow

# 更新缓存
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --update

# 写入 TFS 配置
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --write-tfs-config --pat "<PAT>" --collection "<集合名>"
```

## TFS 权限配置

安装 `ai-tfs-integration` 技能后，需要配置 TFS 权限：

### 收集信息

1. **TFS 个人访问令牌 (PAT)**
   - 在 TFS 中：用户设置 → 安全 → 个人访问令牌 → 创建新令牌

2. **TFS 集合名称**
   - 可选值：`WINNING-6.0`（推荐）、`WN_TECH`、`wn_his`、`WN_PH-Platform`

### 配置文件位置

配置存储在技能目录内：

```
~/.claude/skills/ai-tfs-integration/config/tfs-config.json
```

配置内容：

```json
{
  "serverUrl": "http://tfs2018-web.winning.com.cn:8080/tfs/<集合名>",
  "pat": "<您的PAT>",
  "defaultCollection": "<集合名>"
}
```

## 缓存机制

本技能使用缓存提高效率：

### Registry 缓存

- 位置：`~/.cache/WinCode/registry.json`
- 内容：TFS 技能仓库列表
- 有效期：24小时内不重复刷新

### 技能源码缓存

- 位置：`~/.cache/WinCode/skill/<技能名>/`
- 内容：Git Clone 的技能源码
- 安装方式：创建符号链接（不复制文件）

缓存优势：
- 一次克隆，多处安装
- 所有安装位置共享同一份源码
- 更新缓存后自动同步

## 注意事项

1. **独立运行**：本技能直接从 TFS 仓库安装，无需依赖其他技能
2. **凭据安全**：PAT 仅存储在本地技能目录，不会上传到远程
3. **配置迁移**：配置文件随技能目录存储，可迁移到其他电脑
4. **网络要求**：首次安装需要能访问 TFS 服务器

## 常见问题

### Q: 安装时提示 `[NEED_CREDENTIALS]`

A: TFS 认证失败，需要提供域账户凭据。AI 会引导您输入用户名和密码。

### Q: 技能安装后如何使用？

A: 直接在对话中描述您的需求，如"开发需求 12345"，相关技能会自动触发。

### Q: 如何更新已安装的技能？

A: 运行 `--update` 命令更新缓存，已安装的技能会自动同步最新版本。

### Q: 项目级和全局安装有什么区别？

A: 全局安装所有项目可用；项目级仅当前项目可用，适合特定配置需求。

## 版本信息

- **版本**: 3.0.0
- **作者**: AI事业部
- **技能类型**: skills, installer, auto-dev, ai-devops, tfs
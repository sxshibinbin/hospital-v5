---
name: ai-auto-dev-setup
description: |
  AI事业部全流程自动化研发技能一键安装工具。
  
  **⚠️ CRITICAL TRIGGER RULE - 必须先询问用户**:
  当用户请求"安装"、"一键安装"、"更新"、"配置"技能时，**必须立即停止**。
  在调用任何脚本命令之前，**必须先使用 AskUserQuestion 询问用户**:
  1. 安装位置（全局/项目级）
  2. 如果后续检测到 [NEED_CREDENTIALS]，必须询问 TFS 凭据
  
  **绝对禁止**: 未经询问直接执行 python main.py 脚本命令
  
  触发场景：用户说"安装全自动化研发流程"、"安装auto-dev-pro"、"安装AI事业部技能"、
  "一键安装研发技能"、"配置全流程研发环境"、"安装AI自动开发工具"、"更新技能"、
  "更新全部技能"、"更新工作流程技能"、"拉取最新技能"等。
  
  核心功能：
  1. 一键安装全自动化研发流程（10个技能）
  2. 单独安装任意技能
  3. 支持全局安装（用户级）和项目级安装
  4. 自动配置 ai-tfs-integration 的 TFS 权限（PAT、Collection）
  5. GitNexus 全局安装与配置
  6. 批量更新已安装技能（git pull）
  
  **CRITICAL: 执行脚本前必须先询问用户以下问题：**
  - 安装位置（全局/项目级）
  - TFS 凭据（如果检测到 [NEED_CREDENTIALS] 标记）
tags: [skills, installer, auto-dev, ai-devops, tfs, update]
keywords: [安装技能, 全自动化研发, ai-auto-dev, 一键安装, 技能管理, AI事业部, 更新技能, 拉取技能]
allowed-tools: Bash, AskUserQuestion, Read, Write
metadata:
  author: AI事业部
  version: 4.5.0
  changelog: |
    v4.5.0:
    - 重构流程衔接机制，确保步骤 0-8 按顺序完整执行
    - 添加流程总览图，明确脚本执行与模型执行的边界
    - 脚本输出标记改为 [CONTINUE_TO_SKILL_STEP_6]，与 SKILL.md 流程一致
    - 步骤 6-8 添加明确的衔接信号和输出标记
    - 添加 [FLOW_COMPLETE] 流程结束标记
    v4.4.1:
    - 修复流程在Step 6过早终止的问题
    - Step 6改为中间确认步骤，强制继续到Step 7
    - 脚本输出添加 [CONTINUE_TO_STEP_7] 标记
    - SKILL.md与脚本输出信号联动
    v4.4.0:
    - 新增第7步：知识库生成（调用 ai-architecture-design 技能）
    - 前置条件检查：GitNexus 索引状态、技能安装状态
    - 知识库生成失败不阻断流程，降级处理继续生成引导文档
    v4.3.0:
    - 技能安装后删除 .git 目录（只读模式，无法提交修改）
    - 更新技能改为重新 clone（删除旧缓存后重新获取）
    v4.2.0:
    - 新增自动检测 GitNexus setup/analyze 状态功能
    - GitNexus 流程全自动执行，无需用户确认
    - 已执行过的步骤自动跳过
---

# ai-auto-dev-setup - AI事业部全流程自动化研发安装工具

一键安装 AI 事业部多 Agent 编排体系的全部技能。

## ⚠️ 执行前必须完成的步骤（强制）

**🔴 禁止跳过此步骤！在调用任何脚本命令之前，Claude Code 必须先执行以下询问流程：**

### 步骤 0.0：询问安装位置（强制）

**使用 AskUserQuestion 向用户询问：**

```markdown
问题：请选择技能安装位置：
选项：
- 全局安装（推荐）- 安装到 ~/.claude/skills，所有项目可用
- 项目级安装 - 安装到当前项目 .claude/skills，仅本项目可用
```

**必须等待用户选择后，记录安装位置（`global` 或 `project`），才能继续执行。**

> **🔴 违规示例（绝对禁止）**: 
> ```
> # 错误！未经询问直接执行脚本
> python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --workflow ai-auto-dev
> ```

## 工作原理

```
用户请求 ──必须先询问──→ 收集安装位置 + TFS凭据
                          │
                          ↓
                    调用脚本执行安装（带参数）
                          │
                          ↓
                    Git Clone → 创建符号链接 → TFS权限配置
```

本技能直接从 TFS WinCode/Skill 仓库克隆并安装技能，无需依赖其他技能。

## 使用时机

用户需要：
- 一键安装全流程自动化研发环境
- 单独安装某个 AI 事业部技能
- 在新项目或新机器上快速配置开发环境
- 更新已安装的技能（拉取远程仓库最新内容）
- 批量更新工作流程中的所有技能

## 清单映射

### 全自动化研发流程（ai-auto-dev）

| 类型 | 名称 | 说明 | 必需 | 需配置 |
|------|------|------|------|--------|
| 技能 | ai-auto-dev | 主调度技能 | ✓ | - |
| 技能 | ai-tfs-integration | TFS集成 | ✓ | ✓ |
| 技能 | ai-prd-auto | 需求分析 | ✓ | - |
| 技能 | ai-architecture-design | 架构设计 | ✓ | - |
| 技能 | ai-backend-dev-pro | 后端开发 | ✓ | - |
| 技能 | ai-frontend-dev-pro | 前端开发 | ✓ | - |
| 技能 | ai-code-review-agent | 代码审查 | ✓ | - |
| 技能 | ai-automated-test-agent | 自动化测试 | ✓ | - |
| 技能 | ai-git-merge | 合并分支 | ✓ | - |
| 技能 | ai-git-push | 代码提交 | ✓ | - |

## 执行流程

> **CRITICAL**: 以下步骤必须按顺序执行。Claude Code **不能跳过第 0 步直接调用脚本**。

### 流程总览图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ai-auto-dev-setup 完整流程                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  【用户请求】                                                                │
│      │                                                                      │
│      ↓                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 步骤 0-2：模型执行（脚本前准备）                                        │   │
│  │ - 步骤 0：AskUserQuestion 询问安装位置                                 │   │
│  │ - 步骤 1：解析用户意图                                                 │   │
│  │ - 步骤 2：检查 TFS 凭据（如需要则询问）                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│      │                                                                      │
│      ↓ 调用脚本                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 步骤 3-5：脚本执行（自动化安装）                                        │   │
│  │ - 步骤 3：技能安装（符号链接）                                         │   │
│  │ - 步骤 4：TFS 权限配置（ai-tfs-integration）                           │   │
│  │ - 步骤 5：GitNexus 安装与配置                                          │   │
│  │ 输出标记：[SCRIPT_COMPLETE] [CONTINUE_TO_SKILL_STEP_6]                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│      │                                                                      │
│      ↓ 模型继续执行（收到脚本输出标记后）                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 步骤 6-8：模型执行（流程后阶段）                                        │   │
│  │ - 步骤 6：AskUserQuestion 安装结果确认                                 │   │
│  │   输出标记：[STEP_6_COMPLETE] → 继续步骤 7                             │   │
│  │ - 步骤 7：知识库生成（调用 ai-architecture-design）                    │   │
│  │   输出标记：[STEP_7_COMPLETE] → 继续步骤 8                             │   │
│  │ - 步骤 8：生成引导文档 + 最终确认                                      │   │
│  │   输出标记：[FLOW_COMPLETE] 流程结束                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│      │                                                                      │
│      ↓                                                                      │
│  【流程完成】                                                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

关键衔接信号：
- [SCRIPT_COMPLETE] + [CONTINUE_TO_SKILL_STEP_6] → 脚本完成，继续步骤 6
- [STEP_6_COMPLETE] → 步骤 6 完成，继续步骤 7
- [STEP_7_COMPLETE] → 步骤 7 完成，继续步骤 8
- [FLOW_COMPLETE] → 流程全部完成，可以结束
```

### 第 0 步：必须先询问用户（AskUserQuestion）

**在执行任何脚本命令之前，必须使用 AskUserQuestion 询问用户：**

```markdown
问题：请选择安装位置：
选项：
- 全局安装（推荐）- 安装到 ~/.claude/skills，所有项目可用
- 项目级安装 - 安装到当前项目 .claude/skills，仅本项目可用
```

记录用户选择的位置（`global` 或 `project`），后续调用脚本时传递 `--location <用户选择>`。

### 第 1 步：解析用户意图

根据用户输入判断安装模式：

| 用户输入示例 | 安装模式 |
|-------------|----------|
| "安装全自动化研发流程" | 一键全安装 |
| "安装 ai-auto-dev" | 一键全安装 |
| "一键安装研发技能" | 一键全安装 |
| "安装 ai-tfs-integration" | 单独安装技能 |
| "查看清单" | 查看清单 |

### 第 2 步：检查 TFS 凭据（必须）

运行凭据检查命令：

```bash
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --update
```

**如果输出包含 `[NEED_CREDENTIALS]` 标记，必须执行凭据收集流程：**

使用 `AskUserQuestion` 向用户询问（一次询问，两个问题）：
- 问题 1：`"请提供您的 TFS 域用户名（如 domain\\username）："`（文本输入，选择 "Other"）
- 问题 2：`"请提供您的 TFS 域密码："`（文本输入，选择 "Other"）

收集到凭据后，记录用户名和密码，后续所有脚本调用传递 `--cred-user "用户名" --cred-pass "密码"`。

> **注意**：即使凭据检查通过，后续安装命令也应传递凭据参数以确保 clone 操作成功。

### 第 3 步：执行安装（带完整参数）

调用脚本执行安装时，**必须传递以下参数**：
- `--location <global|project>`（用户在第 0 步选择的值）
- `--cred-user "用户名" --cred-pass "密码"`（如果在第 2 步收集了凭据）

```bash
# 一键全安装（带完整参数）
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --workflow ai-auto-dev --location global --cred-user "用户名" --cred-pass "密码"

# 单独安装技能（带完整参数）
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --skill <SKILL_NAME> --location global --cred-user "用户名" --cred-pass "密码"
```

脚本会：
1. 读取 `references/manifest.yaml` 获取清单
2. 从 TFS WinCode/Skill 仓库克隆每个技能（显示进度）
3. 创建符号链接到目标目录
4. 对于标记 `needs_config: true` 的技能，安装完成后执行配置流程

### 第 4 步：TFS 权限配置（仅 ai-tfs-integration）

**触发条件**：
- 一键安装流程中包含 ai-tfs-integration
- 或单独安装 ai-tfs-integration

**配置流程**：

#### 5.1 检查配置文件是否存在

ai-tfs-integration 的配置文件位于技能目录内：
- 路径：`~/.claude/skills/ai-tfs-integration/config/tfs-config.json`

如果配置文件已存在且包含有效 PAT，跳过配置流程。

#### 5.2 收集 TFS 凭据（使用 AskUserQuestion）

使用 `AskUserQuestion` 向用户询问（一次询问，两个问题）：

- 问题 1：`"请提供您的 TFS 个人访问令牌 (PAT)："`
  - 提示：`TFS → 用户设置 → 安全 → 个人访问令牌 → 创建新令牌`
  - 选择 "Other" 进行文本输入

- 问题 2：`"请选择您的默认 TFS 集合："`
  - 选项：
    - `WINNING-6.0`（推荐）
    - `WN_TECH`
    - `wn_his`
    - `WN_PH-Platform`
    - `其他（手动输入）`

> TFS_URL 默认为 `http://tfs2018-web.winning.com.cn:8080/tfs`

#### 5.3 写入配置文件

将收集的凭据写入 `~/.claude/skills/ai-tfs-integration/config/tfs-config.json`：

```json
{
  "serverUrl": "http://tfs2018-web.winning.com.cn:8080/tfs/<用户选择的集合>",
  "pat": "<用户输入的PAT>",
  "defaultCollection": "<用户选择的集合>"
}
```

#### 5.4 确认配置成功

使用本技能脚本验证配置：

```bash
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --write-tfs-config --pat "<PAT>" --collection "<集合名>"
```

### 第 5 步：GitNexus 安装与配置（全局安装，全自动）

> **重要说明**：GitNexus 是 npm 全局工具，始终通过 `npm install -g gitnexus` 安装到系统全局，不受第 2 步用户选择的影响。这是因为 GitNexus 作为命令行工具需要在所有项目中可用。

**触发条件**：一键安装流程成功完成后，或用户明确请求安装 GitNexus

**全自动流程（无需用户确认）**：
脚本会自动判断 GitNexus 的安装状态和配置状态，自动执行必要的步骤：
- 已安装 → 跳过安装
- 已执行 setup → 跳过配置
- 已执行 analyze → 跳过索引

### 5.1 检查 Node.js 环境

GitNexus 需要 Node.js 18+ 环境。脚本会自动检查：

```bash
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --check-nodejs
```

如果输出包含 `[NODEJS_OK]`，表示环境满足；如果输出包含 `[NODEJS_MISSING]` 或 `[NODEJS_VERSION_LOW]`，需要引导用户安装 Node.js：

使用 `AskUserQuestion` 向用户询问：

```markdown
问题：当前环境 Node.js 版本不满足要求（需要 18+）。请选择处理方式：
选项：
- 自动安装（推荐）- 自动下载并安装 Node.js LTS 版本
- 手动安装 - 我将自行安装 Node.js，完成后继续
- 跳过 GitNexus - 暂不安装 GitNexus，后续可手动安装
```

### 5.2 自动执行 GitNexus 安装流程

脚本自动执行以下步骤（无需用户干预）：

**步骤 A：检查 GitNexus 是否已安装**
- 调用 `check_gitnexus_installed()` 检查 npm 全局安装状态
- 如果输出包含 `[GITNEXUS_INSTALLED]`，跳过安装步骤

**步骤 B：安装 GitNexus（如未安装）**
```bash
npm install -g gitnexus
```

**步骤 C：检查 setup 是否已执行**
- 调用 `check_gitnexus_setup_done()` 检查配置文件是否存在
- 检查位置：`~/.gitnexus/config.json`、`~/.config/gitnexus/config.json`
- 如果输出包含 `[GITNEXUS_SETUP_DONE]`，跳过配置步骤

**步骤 D：执行 gitnexus setup（如未配置）**
```bash
gitnexus setup
```

此命令会初始化 GitNexus 配置文件，无需用户输入参数。

**步骤 E：检查 analyze 是否已执行**
- 调用 `check_gitnexus_analyze_done()` 检查项目索引状态
- 检查位置：`~/.gitnexus/data/`、`~/.local/share/gitnexus/`
- 如果输出包含 `[GITNEXUS_ANALYZE_DONE]`，跳过索引步骤

**步骤 F：执行 gitnexus analyze（如项目未索引）**
```bash
gitnexus analyze
```

> **重要提示**：此命令会自动下载嵌入模型（embedding model），首次执行可能需要几分钟时间下载。脚本会自动执行，无需用户确认。

### 5.3 安装结果报告

脚本执行完成后会输出：
- `[i] GitNexus 已安装，跳过安装步骤` - 已安装
- `[i] GitNexus setup 已执行，跳过配置步骤` - 已配置
- `[i] 项目已索引，跳过 analyze 步骤` - 已索引
- `[OK] GitNexus 项目索引完成` - 新索引完成

### 第 6 步：安装结果确认（脚本执行后的第一个 SKILL.md 步骤）

> **⚠️ 关键说明：脚本执行（步骤 3-5）完成后，模型必须继续执行此步骤！**
>
> **脚本输出信号**：当脚本输出 `[SCRIPT_COMPLETE]` 和 `[CONTINUE_TO_SKILL_STEP_6]` 标记时：
> - 表示脚本阶段完成（技能安装 + GitNexus 配置）
> - **必须立即执行此步骤（步骤 6）**
> - **此步骤完成后必须继续步骤 7 → 步骤 8**
>
> **流程序列**：脚本执行（步骤 3-5） → 步骤 6 → 步骤 7 → 步骤 8 → 流程结束

使用 `AskUserQuestion` 向用户展示安装结果：

```markdown
问题：技能安装完成！GitNexus 配置已完成。接下来将自动生成项目知识库...
选项：
- 继续生成知识库（推荐）- 自动执行第 7 步知识库生成
- 查看安装详情 - 列出已安装的技能和 GitNexus 状态，然后继续第 7 步
```

**⚠️ 关键：用户选择任何选项后，都必须继续执行第 7 步！**

输出安装摘要（供用户确认）：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  第 6 步：安装结果确认
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

安装位置: {全局/项目级}安装
研发流程技能: {数量} 个成功、0 个失败
  - ai-auto-dev ✓
  - ai-tfs-integration ✓ (已配置)
  - ai-prd-auto ✓
  - ai-architecture-design ✓
  - ai-backend-dev-pro ✓
  - ai-frontend-dev-pro ✓
  - ai-code-review-agent ✓
  - ai-automated-test-agent ✓
  - ai-git-merge ✓
  - ai-git-push ✓
  - ai-project-knowledge ✓

TFS配置: ✓ 已写入
  - 集合: {用户选择的集合}
  - 配置路径: ~/.claude/skills/ai-tfs-integration/config/tfs-config.json

Node.js: ✓ 满足要求 (v{版本})
GitNexus: ✓ 已安装 (v{版本})
  - setup: ✓ 已执行
  - analyze: {✓ 已索引 / ⏳ 需要索引}

使用指南: ✓ 已生成
  - 路径: {引导文档路径}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  进入第 7 步：知识库生成...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**强制继续第 7 步**：无论用户选择什么选项，都必须立即进入第 7 步执行知识库生成。

---

### 第 7 步：知识库生成（步骤 6 完成后必须执行）

> **⚠️ 步骤衔接规则**：步骤 6 AskUserQuestion 完成后，**必须立即执行此步骤**。
>
> **流程序列**：步骤 6 → 步骤 7（此步骤）→ 步骤 8 → 流程结束
>
> **此步骤完成后输出标记**：`[STEP_7_COMPLETE] 请继续执行步骤 8：生成引导文档`

> **目的**：利用已安装的 GitNexus 和 ai-architecture-design 技能，自动生成项目知识库文件，为后续架构设计提供基础数据源。

**触发条件**：一键安装流程成功完成后（包含 ai-architecture-design 技能）

#### 7.1 前置条件检查

在调用 ai-architecture-design 之前，必须检查以下前置条件：

| 条件 | 检查方法 | 不满足时的处理 |
|------|----------|---------------|
| GitNexus 已索引项目 | 调用脚本 `--check-gitnexus-analyze`，检查输出是否含 `[GITNEXUS_ANALYZE_DONE]` | 警告并跳过知识库生成 |
| ai-architecture-design 技能已安装 | 检查技能目录是否存在 | 警告并跳过知识库生成 |
| 项目根目录存在 | 检查当前工作目录是否为 git 仓库 | 警告并跳过知识库生成 |

**前置条件检查脚本调用**：

```bash
# 检查 GitNexus 索引状态
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --check-gitnexus-analyze

# 检查 ai-architecture-design 技能是否已安装
# 全局安装：检查 ~/.claude/skills/ai-architecture-design/SKILL.md
# 项目级安装：检查 <项目根目录>/.claude/skills/ai-architecture-design/SKILL.md
```

#### 7.2 前置条件满足 → 执行知识库生成

**调用 ai-architecture-design 技能的步骤0（知识库就绪检查与自动生成）**：

ai-architecture-design 技能在步骤0会自动执行以下逻辑：
1. 检查 `DOCS/项目知识库/初始架构/` 下 6 个文件是否存在
2. 若存在缺失，自动检测数据源（优先 GitNexus 图谱）
3. 使用 GitNexus 查询 + LLM 自动生成缺失文件
4. 生成项目总览文档 `DOCS/项目知识库/{项目名}-knowledge.md`

**调用方式**：

向 Claude Code 下发指令，让它执行 ai-architecture-design 技能的步骤0逻辑：

```
执行 ai-architecture-design 技能的步骤0：知识库就绪检查与自动生成

输入参数：
- 项目根目录：<当前工作目录>
- GitNexus 状态：已索引

执行内容：
1. 检查 DOCS/项目知识库/初始架构/ 下 6 个文件
2. 对缺失文件，使用 GitNexus 查询（优先级1）+ 代码扫描（降级）自动生成
3. 生成项目总览文档 DOCS/项目知识库/<项目名>-knowledge.md
4. 输出步骤0摘要报告

不阻断流程：
- 若知识库生成失败，记录 WARN 日志，继续生成引导文档
```

**知识库生成的预期产物**：

```
DOCS/项目知识库/初始架构/
├── architecture_patterns.md      ✅ 已就绪（已有或自动生成）
├── database_design_standard.md   ✅ 已就绪
├── api_design_standard.md        ✅ 已就绪
├── coding_standard.md            ✅ 已就绪
├── medical_compliance.md         ⚠️ 自动生成（含 [待人工确认]）
├── design_mistakes.md            ✅ 已就绪

DOCS/项目知识库/
├── ICIS-knowledge.md             🆕 从6文件聚合生成
```

#### 7.3 前置条件不满足 → 降级处理

若任一前置条件不满足，**不阻断安装流程**，执行降级处理：

1. 输出警告信息：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⚠️ 知识库生成已跳过
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  前置条件检查结果：
  - GitNexus 索引：❌ 未索引（需先执行 gitnexus analyze）
  - ai-architecture-design 技能：✅ 已安装
  - 项目根目录：✅ 存在

  建议：
    gitnexus analyze --skip-git

  安装流程将继续执行（生成引导文档）...
```

2. 在引导文档中添加知识库状态说明
3. 继续执行第 8 步（生成引导文档）

#### 7.4 知识库生成结果报告

知识库生成完成后，输出摘要：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  步骤7：知识库生成 完成
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  数据源: GitNexus (119,258 节点 / 1,700 聚类) + 代码直接扫描

  📄 architecture_patterns.md      ✅ 已就绪 (已有)
  📄 database_design_standard.md   ✅ 已就绪 (已有)
  📄 api_design_standard.md        🆕 自动生成 (GitNexus 聚类 + Controller 扫描)
  📄 coding_standard.md            🆕 自动生成 (代码统计采样 30 个类)
  📄 medical_compliance.md         ⚠️ 自动生成 (代码合规扫描，3 项 [待人工确认])
  📄 design_mistakes.md            🆕 自动生成 (反模式扫描，4 条 @ 置信度 60-90%)
  📄 ICIS-knowledge.md             🆕 从6文件聚合生成

  进入步骤8（生成引导文档）...
```

### 第 8 步：生成引导文档并完成流程（最终步骤）

> **⚠️ 步骤衔接规则**：步骤 7 完成后，**必须立即执行此步骤**。
>
> **流程序列**：步骤 7 → 步骤 8（此步骤，流程终点）
>
> **此步骤完成后输出标记**：`[FLOW_COMPLETE] 安装流程全部完成`

安装成功后，自动在技能安装目录生成使用指南：

- 全局安装：`~/.claude/skills/全自动化研发.md`
- 项目级安装：`<项目根目录>/.claude/skills/全自动化研发.md`

引导文档包含：
- 快速开始命令示例
- 研发流程阶段说明
- 单阶段使用方法
- TFS 工作项操作
- GitNexus 核心命令使用指南
- **知识库状态说明**（新增：记录步骤7的生成结果或跳过原因）
- 最佳实践建议
- 常用命令速查表

引导用户打开该文档查看详细使用说明：

```markdown
问题：安装完成！使用指南已生成，是否立即查看？
选项：
- 查看指南（推荐）- 打开 全自动化研发.md
- 开始使用 - 直接输入"开发需求 <编号>"
- 完成 - 结束安装流程（输出 [FLOW_COMPLETE] 标记）
```

> **⚠️ 流程结束规则**：无论用户选择什么选项，在执行完用户请求的操作后：
> - 必须输出 `[FLOW_COMPLETE] 安装流程全部完成` 标记
> - 此标记表示技能执行完毕，流程结束

## 命令参考

### 一键安装
```bash
# 安装全自动化研发流程（全局）
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --workflow ai-auto-dev --location global

# 安装全自动化研发流程（项目级）
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --workflow ai-auto-dev --location project
```

### 单独安装技能
```bash
# 安装单个技能
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --skill <SKILL_NAME> --location global
```

### 更新缓存
```bash
# 更新 TFS 仓库缓存
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --update
```

### TFS 配置
```bash
# 写入 TFS 配置（供 SKILL.md 流程调用）
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --write-tfs-config --pat "<PAT>" --collection "<集合名>"
```

### GitNexus 相关
```bash
# 检查 Node.js 环境
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --check-nodejs

# 检查 GitNexus 是否已安装
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --check-gitnexus

# 安装 GitNexus（npm 全局安装）
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --install-gitnexus

# 检查 gitnexus setup 是否已执行（自动检测配置文件）
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --check-gitnexus-setup

# 执行 gitnexus setup（如未配置）
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --gitnexus-setup

# 检查项目是否已索引（自动检测索引状态）
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --check-gitnexus-analyze

# 执行 gitnexus analyze（如项目未索引）
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --gitnexus-analyze
```

### 技能更新
```bash
# 更新工作流程中的所有技能（默认 ai-auto-dev）
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --update-skills

# 更新指定工作流程的技能
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --update-skills --update-workflow <WORKFLOW_NAME>

# 更新单个技能
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --update-skill <SKILL_NAME>
```

### 查看状态
```bash
# 列出可用技能
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --list

# 查看工作流程清单
python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --list-workflow
```

## 交互示例

**一键安装全流程：**
```
用户: 安装全自动化研发流程

AI 执行:
1. 询问安装位置 → 用户选择"全局安装"
2. 更新缓存 → 成功
3. 执行批量安装...
   [OK] ai-auto-dev 已安装
   [OK] ai-prd-auto 已安装
   [OK] ai-architecture-design 已安装
   ...
   [OK] ai-tfs-integration 已安装
4. 检测 ai-tfs-integration 需要配置 → 询问 TFS 凭据
5. 用户输入 PAT 和选择 Collection
6. 写入配置文件 ~/.claude/skills/ai-tfs-integration/config/tfs-config.json
7. 知识库生成（调用 ai-architecture-design 步骤0）
   - 检查前置条件：GitNexus 已索引 ✓
   - 检查知识库文件：2/6 缺失
   - 自动生成缺失文件（使用 GitNexus 图谱）
   - 生成项目总览文档 ICIS-knowledge.md
8. 生成使用指南 → ~/.claude/skills/全自动化研发.md
9. 提示安装完成

安装完成！已安装 11 个技能。
知识库已生成：DOCS/项目知识库/初始架构/ (6文件) + ICIS-knowledge.md
使用指南已生成，请打开 全自动化研发.md 查看详细使用方法。
```

**单独安装技能：**
```
用户: 安装 ai-tfs-integration

AI 执行:
1. 更新缓存 → 成功
2. 从 TFS 仓库克隆技能 → 创建符号链接
   [OK] ai-tfs-integration 已安装
3. 检测需要配置 → 询问 TFS 凭据
4. 写入配置文件

安装完成！TFS 集成已配置。
```

**更新技能：**
```
用户: 更新全部技能

AI 执行:
更新工作流程: 全流程自动化研发
共 11 个技能

[1/11] ai-auto-dev
  [i] ai-auto-dev: 已是最新版本
[2/11] ai-tfs-integration
  [OK] ai-tfs-integration: 已更新
      Updating...
[3/11] ai-prd-auto
  [OK] ai-prd-auto: 已更新
...

更新完成
  已更新: 3 个
  无变化: 8 个
  更新失败: 0 个

已更新技能:
  ✓ ai-tfs-integration
  ✓ ai-prd-auto
  ✓ ai-backend-dev-pro

技能已同步到最新版本！
```

**更新单个技能：**
```
用户: 更新 ai-tfs-integration

AI 执行:
  更新 ai-tfs-integration...
  [OK] ai-tfs-integration: 已更新

技能已更新完成。
```

## 注意事项

1. **独立安装工具**：本技能直接从 TFS 仓库安装，无需依赖其他技能
2. **凭据安全**：PAT 等敏感信息仅存储在 ai-tfs-integration 技能目录内，不会上传到远程
3. **项目级安装**：技能安装到当前项目的 `.claude/skills/` 目录
4. **配置迁移**：ai-tfs-integration 的配置文件随技能目录一起存储，可随技能迁移到其他电脑
5. **技能更新**：更新操作从远程仓库拉取最新内容，不会影响本地配置文件
6. **符号链接**：技能通过符号链接关联，更新缓存仓库后所有项目自动同步
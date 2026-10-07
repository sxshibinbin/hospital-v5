---
name: ai-auto-dev
description: |
  AI医疗事业部多Agent编排总调度中枢 - 多需求并行自动开发的完整解决方案。

  **触发此技能的场景**（包含以下任一即触发）：
  - 用户明确说 "ai-auto-dev" 或 "多需求并行开发" + 需求号列表
  - 用户要求批量自动处理多个需求的开发任务
  - 用户需要一个总调度来协调多个编码Agent并行工作
  - 用户提到 "多Agent编排"、"全链路自动开发"、"并行调度"

  **核心能力**：多任务并行调度、Git Worktree隔离、步骤监控、重试机制、过程追踪

  **智能调度**：自动识别可用技能，通过子Agent执行，无需硬编码配置

  **⚠️ 自动执行模式**：此技能采用顺序推进模式，从 Step 0 顺序执行到 Step 11。每完成一个步骤立即推进到下一个，不等待用户输入，直到所有步骤完成。

  **⚠️ 子Agent强制执行原则**：所有步骤必须通过子Agent调用对应技能，禁止触发兜底逻辑直接用大模型处理。

  **⚠️ 禁止流程简化**：无论任务看起来多么简单，都必须完整执行所有步骤。禁止因"简单任务"判断而跳过任何步骤、简化流程或直接执行 git 命令。

  **⚠️ 前置依赖（新增智能补全）**：
  - Step 0.5 新增前置文档智能检查逻辑
  - 前置文档缺失时自动检查 TFS 附件 → 调用 ai-prd-auto 补全
  - 确保流程不中断，无需手动准备前置文档

tags: [自动开发, 多任务并行, Agent编排, 全链路, 总调度中枢, 智能调度]
keywords: [ai-auto-dev, 批量自动开发, 多需求并行, Agent编排, 总调度, worktree, 智能识别]
priority: 10
requires_tools: [Agent, Bash, Read, Edit, Write, Glob, Grep]
requires_bins: [git]
metadata:
  author: lzw3
  version: 6.5.0
  changelog: |
    - v6.5.0: 适配 ai-prd-auto 前置分支创建；Step 1 检测已存在的 feature 分支并复用；Step 1.5 补充 DOCS 同步说明
    - v6.4.0: 新增前置文档智能检查逻辑：Step 0.5 改为检查DOCS/附件/调用ai-prd-auto自动补全
    - v6.3.0: 新增 Step 0.6 子技能存在性验证；技能不存在时强制询问用户；强化禁止自主判断约束
    - v6.2.0: 强化禁止流程简化的约束；Step 6 子Agent prompt 补充 Step 7/8 TFS 状态更新步骤
    - v6.1.0: 新增 Step 0.0 前置分支检查，确保当前分支已提交后再创建 worktree
    - v6.0.0: 初始版本
---

# ai-auto-dev 多Agent编排总调度中枢

## 概述

ai-auto-dev 统一接管全事业部所有产品线的AI自动化研发全流程（编码→评审→测试→提交）。

**⚠️ 关键说明**：此技能专注于开发执行阶段，但新增前置文档智能检查功能：
- **Step 0.5 新增功能**：前置文档缺失时自动补全
  - Phase 1：检查 DOCS/{需求号}/ 目录是否有前置文档
  - Phase 2：检查 TFS 需求附件（通过 ai-tfs-integration）
  - Phase 3：调用 ai-prd-auto 自动生成需求设计文档

**核心职责**：多任务并行调度、Git Worktree管理、步骤监控与重试、过程文档追踪、前置文档智能补全

---

## ⛔ 禁止流程简化与技能缺失处理（强制遵守）

**这是最重要的原则，违反此原则将导致流程失败！**

```
┌─────────────────────────────────────────────────────────────────┐
│  ⛔ 禁止流程简化原则                                              │
├─────────────────────────────────────────────────────────────────┤
│  1. 禁止因"简单任务"判断而简化流程                                 │
│  2. 禁止直接执行 git 命令跳过 ai-git-push 技能                     │
│  3. 禁止跳过任何子Agent调用（Step 2/3/4/5/6 必须调用）             │
│  4. 禁止跳过 ai-git-push 的 Step 7/8（TFS 状态更新）              │
│  5. 禁止自主判断"任务不需要完整流程"                               │
│  6. 所有任务，无论复杂度，都必须完整执行所有步骤                    │
│  7. ⛔ 技能不存在时禁止自主跳过，必须询问用户                       │
└─────────────────────────────────────────────────────────────────┘
```

**常见错误示例**：

| 错误行为 | 正确做法 |
|----------|----------|
| ❌ "只有代码提交，直接 git push" | ✅ 调用 ai-git-push 子Agent，执行完整流程包括 Step 7/8 |
| ❌ "简单需求，跳过代码评审" | ✅ 必须调用 ai-code-review-agent 子Agent |
| ❌ "已有测试用例，跳过自动化测试" | ✅ 必须调用 ai-automated-test-agent 子Agent |
| ❌ "不需要更新 TFS 状态" | ✅ ai-git-push 的 Step 7/8 必须执行 |
| ❌ "ai-code-review-agent 不存在，跳过评审" | ✅ **使用 AskUserQuestion 询问用户处理方式** |
| ❌ "ai-automated-test-agent 不存在，跳过测试" | ✅ **使用 AskUserQuestion 询问用户处理方式** |

**为什么必须完整执行流程**：

1. **TFS 状态同步**：Step 7/8 确保子任务和需求状态正确更新，跳过会导致状态不一致
2. **审计追溯**：完整流程确保所有步骤都有记录，便于后续审计
3. **流程完整性**：任何简化都可能遗漏关键检查点，导致流程失败

---

## ⛔ 技能不存在时的强制处理流程

**核心原则**：当检测到子技能文件不存在时，**禁止自主跳过**，必须使用 AskUserQuestion 工具询问用户。

```
┌─────────────────────────────────────────────────────────────────┐
│  ⛔ 技能缺失处理原则                                              │
├─────────────────────────────────────────────────────────────────┤
│  1. 检测到技能文件不存在 → 禁止自主跳过                            │
│  2. 检测到技能文件不存在 → 禁止自主判断"不需要该步骤"               │
│  3. 检测到技能文件不存在 → 必须使用 AskUserQuestion 询问用户       │
│  4. 用户选择"跳过" → 才能跳过该步骤                               │
│  5. 用户选择"暂停" → 流程暂停，等待安装技能                       │
│  6. 用户选择"取消" → 流程终止                                    │
└─────────────────────────────────────────────────────────────────┘
```

**技能缺失询问模板**：

```markdown
AskUserQuestion({
  questions: [
    {
      header: "技能缺失",
      question: "检测到子技能 {技能名称} 文件不存在（路径：{技能路径}）。该技能用于 {步骤名称}，缺失将影响流程完整性。请选择处理方式：",
      multiSelect: false,
      options: [
        {
          label: "跳过该步骤",
          description: "跳过 {步骤名称}，继续执行后续步骤（可能导致流程不完整）"
        },
        {
          label: "暂停流程",
          description: "暂停流程，等待安装技能后重新触发"
        },
        {
          label: "取消流程",
          description: "终止本次自动化开发流程"
        }
      ]
    }
  ]
})
```

**用户选择处理逻辑**：

| 用户选择 | 处理方式 |
|----------|----------|
| 跳过该步骤 | 记录到 sched_log.md，跳过该步骤，继续下一步 |
| 暂停流程 | 输出提示信息，流程暂停，等待用户安装技能 |
| 取消流程 | 输出取消信息，流程终止 |

**⚠️ 禁止的行为**：

- ❌ 检测到技能不存在后，自主决定"简单任务不需要"
- ❌ 检测到技能不存在后，自主跳过不询问用户
- ❌ 检测到技能不存在后，自主用其他方式替代（如用 diff 检查替代代码评审）

---

## ⚠️ 核心执行原则：子Agent强制调用机制

**必须遵守的原则**：

```
┌─────────────────────────────────────────────────────────────────┐
│  子Agent强制执行原则                                              │
├─────────────────────────────────────────────────────────────────┤
│  1. 每个步骤必须通过 Agent 工具调用子Agent                         │
│  2. 子Agent prompt 必须明确指定技能文件路径                        │
│  3. 子Agent 必须严格执行技能定义的流程（禁止自主判断）              │
│  4. 禁止触发兜底逻辑（禁止直接用大模型处理）                        │
│  5. 子技能执行完毕后静默返回，主调度继续下一步                      │
└─────────────────────────────────────────────────────────────────┘
```

**子Agent调用标准模板**：

```markdown
Agent({
    subagent_type: "general-purpose",
    description: "{步骤名称} - 需求号 {需求号}",
    prompt: `
## ⚠️ 强制执行指令

你正在作为 ai-auto-dev 的子 Agent 执行任务。

### 任务信息
- 需求号：{需求号}
- Worktree路径：worktree-{需求号}
- 任务类型：{步骤名称}

### ⚠️ 技能执行要求（强制遵守）

**你必须严格执行以下技能文件定义的流程：**

1. 首先使用 Read 工具读取技能文件：
   - 文件路径：{技能文件路径}

2. **严格按照技能文件中定义的步骤顺序执行**：
   - 技能文件中的每个 Step 必须执行
   - 技能文件中的准出标准必须满足
   - **禁止跳过任何步骤**
   - **禁止自主简化流程**
   - **禁止触发兜底逻辑**

3. 技能文件中引用的 references/ 文件必须按需读取

4. 技能文件中定义的模板必须严格遵循

### 文档路径约定
- 调度日志：worktree-{需求号}/DOCS/{需求号}/sched_log.md
- 执行进度：worktree-{需求号}/DOCS/{需求号}/{步骤目录}/exec_prog.md

### 完成后动作
1. 更新 worktree-{需求号}/DOCS/{需求号}/sched_log.md 对应步骤状态为 success
2. 静默返回，不输出任何状态报告或总结
3. **禁止输出**：
   - ❌ 工作总结框
   - ❌ "完成"提示
   - ❌ "后续建议"
   - ❌ 任何形式的报告
`,
    model: "sonnet"
})
```

---

## ⚠️ 步骤与子技能映射表（强制遵守）

| 步骤 | 步骤名称 | 子技能名称 | 技能文件路径 | 调用方式 | 存在性验证 |
|------|----------|------------|--------------|----------|------------|
| Step 0.0 | 前置分支检查 | ai-git-push（可选） | .claude/skills/ai-git-push/SKILL.md | 主调度执行（用户选择自动提交时调用子Agent） | Step 0.6 验证 |
| Step 0 | 初始化 | 无（自主执行） | - | 主调度执行 | - |
| Step 0.5 | 前置文档智能检查 | ai-tfs-integration（可选） | .claude/skills/ai-tfs-integration/SKILL.md | 子Agent调用（Phase 2附件检查时） | Phase 2 验证 |
| Step 0.5 | 前置文档智能检查 | ai-prd-auto（可选） | .claude/skills/ai-prd-auto/SKILL.md | 子Agent调用（Phase 3自动补全时） | Phase 3 验证 |
| Step 0.6 | 子技能存在性验证 | 无（自主执行） | - | 主调度执行 | ✅ **验证所有子技能** |
| Step 1 | 创建Worktree | 无（自主执行） | - | 主调度执行 | - |
| Step 2 | 后端编码 | ai-backend-dev-pro | .claude/skills/ai-backend-dev-pro/SKILL.md | 子Agent强制调用 | ⚠️ Step 0.6 已验证，缺失则跳过或询问 |
| Step 3 | 前端编码 | ai-frontend-dev-pro | .claude/skills/ai-frontend-dev-pro/SKILL.md | 子Agent强制调用 | ⚠️ Step 0.6 已验证，缺失则跳过或询问 |
| Step 4 | 代码评审 | ai-code-review-agent | .claude/skills/ai-code-review-agent/SKILL.md | 子Agent强制调用 | ⚠️ Step 0.6 已验证，缺失则跳过或询问 |
| Step 5 | 自动化测试 | ai-automated-test-agent | .claude/skills/ai-automated-test-agent/SKILL.md | 子Agent强制调用 | ⚠️ Step 0.6 已验证，缺失则跳过或询问 |
| Step 6 | Git提交 | ai-git-push | .claude/skills/ai-git-push/SKILL.md | 子Agent强制调用 | ⚠️ Step 0.6 已验证，缺失则跳过或询问 |
| Step 7 | 清理前验证 | 无（自主执行） | - | 主调度执行 | - |
| Step 8 | 清理Worktree | 无（自主执行） | - | 主调度执行 | - |
| Step 9-11 | 完成 | 无（自主执行） | - | 主调度执行 | - |

**⚠️ 重要**：
1. Step 0.5 是前置文档智能检查，三阶段逻辑（DOCS→附件→ai-prd-auto补全）
2. Step 0.5 的 Phase 2/Phase 3 按需调用 ai-tfs-integration 或 ai-prd-auto（缺失时询问用户）
3. Step 0.6 是子技能存在性验证，必须最先执行！
4. Step 2/3/4/5/6 必须通过子Agent调用，禁止自主执行！
5. **Step 0.6 检测到技能缺失时，必须询问用户，禁止自主跳过！**

---

## ⚠️ 安全执行原则与 Worktree 管理（必须遵守）

> Claude Code 有两层检查机制：权限白名单（用户配置）+ 安全层（系统强制）。
> **安全层独立于白名单，不可通过配置绕过。** 以下命令模式会被强制拦截：
>
> 1. **`cd ... && git ...` 组合命令** → 安全层强制拦截，触发人工确认
> 2. **在 worktree 目录内执行 git 命令** → 安全层强制拦截，触发人工确认
>
> **正确做法**：
> - 所有 git 命令在项目根目录执行，不使用 `cd` 组合
> - 需要指定目录时使用 `git -C <path>` 参数
> - **⛔ 禁止使用 EnterWorktree 工具**（它会创建 `.claude/worktrees/` 下的 worktree，与规范不一致）

### Worktree 路径规范

| 项目 | 规范 |
|------|------|
| **创建路径** | `{项目根目录}/worktree-{需求号}` |
| **禁止路径** | `{项目根目录}/.claude/worktrees/{需求号}` |
| **工作方式** | 使用 `git -C` 参数或直接指定文件路径 |

### ⛔ 禁止的命令模式（安全层强制拦截）

> **⚠️ 警告：以下命令模式会被 Claude Code 安全层强制拦截，触发人工确认弹窗！**
>
> **无论如何配置白名单，这些命令都会被阻止！请勿尝试执行！**

| 禁止模式 | 原因 | 替代方案 |
|----------|------|----------|
| `cd path && git ...` | 安全层强制拦截 | `git -C path ...` |
| `cd path && mvn ...` | 安全层强制拦截 | `mvn -f path/pom.xml ...` |
| 在 worktree 内执行 `git` | 安全层强制拦截 | 在根目录用 `git -C` |
| `EnterWorktree` 工具 | 创建错误路径 | 直接使用文件路径 |

### ✅ 正确命令示例

```bash
# ✅ 正确 - 创建 worktree（在项目根目录下）
git worktree add worktree-{需求号} -b feature/{需求号} --no-track

# ✅ 正确 - 检查 worktree 状态（使用 git -C 参数）
git -C worktree-{需求号} status --porcelain

# ✅ 正确 - 在 worktree 中编译（指定文件路径）
mvn compile -f worktree-{需求号}/icis/pom.xml -DskipTests

# ✅ 正确 - 清理 worktree
git worktree remove worktree-{需求号} --force
```

---

## 输入参数

**需求号列表**：支持单个或多个需求号（逗号分隔）
- 示例：`260519` 或 `260519,260520,260521`

---

## ⚠️ 目录结构规范（重要）

> **关键设计**：DOCS 目录必须创建在 **worktree 内**，与代码同位置，确保 git-push 子Agent能同时提交代码和文档。

> **前置依赖**：需求设计文档已存在于 DOCS/{需求号}/ 目录下（由 ai-prd-auto 和 ai-architecture-design 技能独立执行产出）

```
DOCS/{需求号}/                    ← 主工作区 DOCS（前置产出物，已就绪）
├── 需求设计/                     ← ai-prd-auto 产出（已存在）
│   ├── requirement.md
│   ├── prototype/
│   └── exec_prog.md
├── 架构设计/                     ← ai-architecture-design 产出（已存在）
│   ├── module_design.md
│   ├── schema.sql
│   ├── api_spec.yaml
│   └── exec_prog.md
└── 任务拆分/
    └── 任务索引.md

worktree-{需求号}/              ← Worktree 根目录（feature 分支）
├── DOCS/{需求号}/              ← ⚠️ DOCS 在 worktree 内（复制自主工作区）
│   ├── sched_log.md           ← 调度日志
│   ├── 需求设计/               ← 从主工作区复制
│   ├── 原型设计/               ← 从主工作区复制（独立目录）
│   ├── 架构设计/               ← 从主工作区复制（如存在）
│   ├── 任务拆分/               ← 从主工作区复制
│   ├── 后端编码/exec_prog.md   ← 后端开发过程记录
│   ├── 前端编码/exec_prog.md   ← 前端开发过程记录
│   ├── 代码评审/exec_prog.md   ← 代码评审记录
│   ├── 自动化测试/exec_prog.md ← 测试记录
│   └── Git提交/exec_prog.md    ← Git提交记录
├── icis/
│   ├── icis-biz-main/
│   │   └── src/main/java/.../monitor/...  ← 后端代码
│   └── icis-ui/
│       └── src/views/...                   ← 前端代码
└── ...
```

### 文档路径约定

所有步骤创建的文档，路径格式为：
```
worktree-{需求号}/DOCS/{需求号}/{步骤}/exec_prog.md
```

---

## 执行流程总览

```
Phase 0: 前置检查（必须最先执行）
    Step 0.0 → 检查当前分支是否已提交 → 未提交则询问用户处理方式 → 进入 Step 0.1

Phase 1: 初始化
    Step 0 → 准备环境、扫描技能、进入 Step 0.5 → 进入 Step 0.6
    Step 0.5 → ⚠️ 前置文档智能检查（三阶段：DOCS→附件→ai-prd-auto补全）→ 进入 Step 0.6
    Step 0.6 → ⚠️ 验证子技能文件是否存在 → 技能缺失则询问用户 → 进入 Step 1
    Step 1 → 创建 Worktree 和分支、复制DOCS文档 → 进入 Step 2

Phase 2: 编码实现（对每个需求号依次执行）
    Step 2  → 后端编码（读取已有需求设计文档，调用子Agent）→ 进入 Step 3
    Step 3  → 前端编码（调用子Agent）→ 进入 Step 4

Phase 3: 质量保障
    Step 4  → 代码评审（调用子Agent）→ 进入 Step 5
    Step 5  → 自动化测试（调用子Agent）→ 进入 Step 6

Phase 4: 交付与清理
    Step 6  → Git提交（调用子Agent）→ 进入 Step 7
    Step 7  → 清理前验证 → 进入 Step 8
    Step 8  → 清理 Worktree → 处理下一个需求号或进入 Phase 5

Phase 5: 完成（所有需求号处理完成后）
    Step 9  → 更新调度日志最终状态 → 进入 Step 10
    Step 10 → 生成执行汇总报告 → 进入 Step 11
    Step 11 → 输出工作总结，流程结束 ← 【唯一允许输出总结的步骤】
```

---

## ⚠️ Step 0.5 前置文档智能检查流程图（新增）

```
需求号 {需求号} 进入 Step 0.5
           │
           ▼
    ┌──────────────┐
    │ Phase 1:     │
    │ DOCS目录检查 │
    └──────────────┘
           │
           ├─── 全部存在 ──────────────────────────────→ ✅ 进入 Step 0.6
           │
           ▼
    ┌──────────────┐
    │ Phase 2:     │
    │ 需求附件检查 │
    │ (ai-tfs-     │
    │  integration)│
    └──────────────┘
           │
           ├─── 技能不可用 ────→ 进入 Phase 3
           │
           ├─── 无附件 ────────────────────→ 进入 Phase 3
           │
           ├─── 有附件 ──→ 复制到DOCS目录 ──→ ✅ 进入 Step 0.6
           │
           ▼
    ┌──────────────┐
    │ Phase 3:     │
    │ 自动补全     │
    │ (ai-prd-auto)│
    └──────────────┘
           │
           ├─── 技能不可用 ──→ AskUserQuestion（跳过/暂停/取消）
           │
           ├─── 调用子Agent执行需求分析
           │
           ├─── 产物验证通过 ─────────────────────→ ✅ 进入 Step 0.6
           │
           └─── 产物验证失败 ──→ AskUserQuestion（重试/跳过/暂停）
```

---

## Phase 1: 初始化

### ⚠️ Step 0.0: 前置分支检查（必须最先执行）

**核心目的**：确保当前工作区已提交，避免后续创建 worktree 和分支时出现冲突。

**⚠️ 关键说明**：此步骤是整个流程的前置条件，如果不执行此检查：
- 创建新分支时可能失败（分支名称冲突）
- 创建 worktree 时可能失败（工作区有未提交更改）
- 后续 git push 步骤无法正常执行

**检查方法**：

```bash
# 检查当前工作区是否有未提交的更改
git status --porcelain
```

**判断标准**：
- 输出为空：工作区干净，可继续执行 → 进入 Step 0.1
- 输出不为空：工作区有未提交的更改 → **必须询问用户处理方式**

**用户询问流程**（使用 AskUserQuestion 工具）：

当发现工作区有未提交的更改时，必须询问用户选择处理方式：

```
AskUserQuestion({
  questions: [
    {
      header: "未提交更改",
      question: "当前工作区有未提交的更改，这将影响后续流程（创建分支和 worktree 可能失败）。请选择处理方式：",
      multiSelect: false,
      options: [
        {
          label: "自动提交（推荐）",
          description: "调用 ai-git-push 技能自动提交当前更改，然后继续流程"
        },
        {
          label: "人工处理",
          description: "暂停流程，等待您手动处理未提交的更改后再继续"
        },
        {
          label: "取消流程",
          description: "终止本次自动化开发流程"
        }
      ]
    }
  ]
})
```

**用户选择处理**：

| 用户选择 | 处理方式 |
|----------|----------|
| 自动提交 | 调用 ai-git-push 技能执行提交，完成后继续 Step 0.1 |
| 人工处理 | 输出提示信息，流程暂停，等待用户处理后重新触发技能 |
| 取消流程 | 输出取消信息，流程终止 |

**自动提交执行指令**（当用户选择"自动提交"时）：

```markdown
Agent({
    subagent_type: "general-purpose",
    description: "提交当前工作区更改",
    prompt: `
## ⚠️ 强制执行指令

你正在作为 ai-auto-dev 的子 Agent 执行前置提交任务。

### 任务信息
- 任务类型：前置提交（提交当前工作区更改）
- 目的：确保工作区干净后再创建 worktree

### ⚠️ 技能执行要求（强制遵守）

**你必须严格执行以下技能文件定义的流程：**

1. 首先使用 Read 工具读取技能文件：
   - 文件路径：.claude/skills/ai-git-push/SKILL.md

2. **严格按照技能文件中定义的步骤顺序执行**
3. **禁止跳过任何步骤**

### 完成后动作
1. 验证工作区状态（git status --porcelain 应为空）
2. 静默返回，不输出任何状态报告或总结
`,
    model: "sonnet"
})
```

**人工处理提示信息**（当用户选择"人工处理"时）：

```
⚠️ 流程暂停 - 需要人工处理

当前工作区有未提交的更改，您选择了人工处理方式。

请按以下步骤操作：
1. 手动提交或暂存当前更改
2. 确保工作区干净后（git status --porcelain 输出为空）
3. 重新触发 ai-auto-dev 技能继续流程

未提交的文件列表：
{列出 git status --porcelain 的输出内容}
```

**取消流程提示信息**（当用户选择"取消流程"时）：

```
⚠️ 流程已取消

您取消了本次自动化开发流程。

当前工作区仍有未提交的更改，建议：
- 使用 ai-git-push 技能提交更改
- 或手动处理后再重新触发 ai-auto-dev 技能
```

**完成后动作**：
- 工作区干净：立即进入 Step 0.1
- 用户选择自动提交且提交成功：进入 Step 0.1
- 用户选择人工处理：流程暂停，等待用户重新触发
- 用户选择取消流程：流程终止

---

### Step 0: 初始化

执行以下步骤：

**Step 0.1**: 解析需求号列表，验证格式有效性
**Step 0.2**: 扫描 `.claude/skills/*/SKILL.md`，构建可用技能索引
**Step 0.3**: 读取 `DOCS/config.env` 获取调度参数配置（主工作区）
**Step 0.4**: 确定并发上限（MAX_CONCURRENT_TASKS）
**Step 0.5**: ⚠️ **前置文档智能检查（新增逻辑）**
**Step 0.6**: ⚠️ **验证子技能文件是否存在（强制执行）**

---

**⚠️ Step 0.5: 前置文档智能检查（必须执行）**

**核心目的**：在流程开始前智能检查前置文档，缺失时自动补全（检查附件→调用ai-prd-auto），确保流程不中断。

**前置文档清单**（每个需求号）：
- `DOCS/{需求号}/需求设计/requirement.md` - 需求设计文档
- `DOCS/{需求号}/需求设计/prototype/` - 原型设计目录
- `DOCS/{需求号}/任务拆分/任务索引.md` - 任务拆分清单

**三阶段检查流程**：

```
┌─────────────────────────────────────────────────────────────────┐
│  Step 0.5 前置文档智能检查流程                                    │
├─────────────────────────────────────────────────────────────────┤
│  Phase 1: DOCS目录检查                                           │
│    → 检查 DOCS/{需求号}/ 是否存在前置文档                         │
│    → 存在：✅ 通过，进入 Step 0.6                                 │
│    → 不存在：进入 Phase 2                                        │
│                                                                  │
│  Phase 2: 需求附件检查                                           │
│    → 通过 ai-tfs-integration 查询需求附件                        │
│    → 有附件：下载/复制到 DOCS/{需求号}/，进入 Step 0.6            │
│    → 无附件：进入 Phase 3                                        │
│                                                                  │
│  Phase 3: 自动补全（调用 ai-prd-auto）                           │
│    → 调用 ai-prd-auto 子Agent进行需求分析                        │
│    → 等待完成后验证产物                                          │
│    → 产物存在：进入 Step 0.6                                     │
│    → 产物不存在：询问用户处理方式                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Phase 1: DOCS目录检查

**检查方法**：使用 Glob 工具检查每个前置文档路径。

```bash
# 检查需求设计文档
Glob({ pattern: "DOCS/{需求号}/需求设计/requirement.md" })

# 检查原型设计目录
Glob({ pattern: "DOCS/{需求号}/需求设计/prototype/*" })

# 检查任务拆分清单
Glob({ pattern: "DOCS/{需求号}/任务拆分/任务索引.md" })
```

**判定标准**：
- **全部存在**：✅ 前置文档完整，进入 Step 0.6
- **部分或全部不存在**：进入 Phase 2 检查附件

**日志记录**：
```
[INFO] Step 0.5-前置文档检查：需求号 {需求号}
       - 需求设计文档：✅ 存在 / ❌ 不存在
       - 原型设计目录：✅ 存在 / ❌ 不存在
       - 任务拆分清单：✅ 存在 / ❌ 不存在
       → 进入 Phase 2（附件检查）
```

---

### Phase 2: 需求附件检查

**触发条件**：Phase 1 检测到前置文档缺失。

**检查方法**：通过 ai-tfs-integration 技能查询 TFS 需求附件。

**⚠️ 前置条件**：需要有 tfs_work_item_id（需求号）。如果需求号不是 TFS 工作项 ID，则跳过此 Phase 直接进入 Phase 3。

**执行步骤**：

1. **验证 ai-tfs-integration 技能可用性**：
   ```
   Glob({ pattern: ".claude/skills/ai-tfs-integration/SKILL.md" })
   ```

2. **技能可用时**：调用子Agent查询附件
   ```markdown
   Agent({
       subagent_type: "general-purpose",
       description: "查询需求附件 - 需求号 {需求号}",
       prompt: `
   ## 任务信息
   - 需求号：{需求号}
   - 任务类型：查询TFS需求附件

   ## 技能执行要求

   1. 首先使用 Read 工具读取技能文件：
      - 文件路径：.claude/skills/ai-tfs-integration/SKILL.md

   2. 按技能文件执行：
      - 查询工作项 {需求号} 的附件列表
      - 附件类型筛选：优先查找 .md、.docx、.pdf 类型的需求文档

   3. 输出格式：
      状态: has_attachments / no_attachments
      附件列表: [附件名称, 附件URL, 附件类型]

   4. 静默返回，不输出任何状态报告或总结
   `,
       model: "haiku"
   })
   ```

3. **有附件时**：下载/复制到 DOCS 目录
   - 如果附件是需求设计文档，复制到 `DOCS/{需求号}/需求设计/`
   - 如果附件是原型设计，复制到 `DOCS/{需求号}/需求设计/prototype/`
   - 如果附件是任务拆分，复制到 `DOCS/{需求号}/任务拆分/`

4. **技能不可用或无附件时**：进入 Phase 3

**日志记录**：
```
[INFO] Step 0.5-附件检查：需求号 {需求号}
       - ai-tfs-integration技能：✅ 可用 / ❌ 不可用
       - 附件数量：{N}个
       → 有附件：复制到DOCS目录，进入Step 0.6
       → 无附件：进入Phase 3（调用ai-prd-auto）
```

---

### Phase 3: 自动补全（调用 ai-prd-auto）

**触发条件**：Phase 1 前置文档缺失 + Phase 2 无附件或技能不可用。

**核心目的**：自动调用 ai-prd-auto 进行需求分析，补全缺失的前置文档。

**⚠️ 关键说明**：这是新增的核心优化逻辑，确保前置文档缺失时流程不中断。

**执行步骤**：

1. **验证 ai-prd-auto 技能可用性**：
   ```
   Glob({ pattern: ".claude/skills/ai-prd-auto/SKILL.md" })
   ```

2. **技能可用时**：调用子Agent执行需求分析

   ```markdown
   Agent({
       subagent_type: "general-purpose",
       description: "需求分析补全 - 需求号 {需求号}",
       prompt: `
   ## ⚠️ 强制执行指令

   你正在作为 ai-auto-dev 的子 Agent 执行前置需求分析任务。

   ### 任务背景
   - 需求号：{需求号}
   - 前置文档缺失，需要调用 ai-prd-auto 补全
   - 目的：生成需求设计文档、原型、任务拆分

   ### ⚠️ 技能执行要求（强制遵守）

   **你必须严格执行以下技能文件定义的流程：**

   1. 首先使用 Read 工具读取技能文件：
      - 文件路径：.claude/skills/ai-prd-auto/SKILL.md

   2. **严格按照技能文件中定义的步骤顺序执行（步骤0-7）**：
      - 步骤0：可行性验证（组织模式）
      - 步骤1：需求收集
      - 步骤2：需求澄清（智能判断）
      - 步骤3：需求分析
      - 步骤4：编写PRD
      - 步骤5：生成原型
      - 步骤6：核验原始需求
      - 步骤7：任务拆分与TFS下发
      - **禁止跳过任何步骤**
      - **禁止自主简化流程**

   3. 执行模式：
      - 使用 **组织模式**（tfs_work_item_id = {需求号}）
      - 产物直接写入 DOCS/{需求号}/

   4. 技能文件中定义的输出格式必须严格遵循

   ### 输入参数
   - tfs_work_item_id：{需求号}
   - context：{}（由技能步骤2自行判断是否需要澄清）

   ### 完成后动作
   1. 验证产物目录：DOCS/{需求号}/需求设计/、DOCS/{需求号}/任务拆分/
   2. 更新调度日志（如果已创建）
   3. 静默返回，不输出任何状态报告或总结

   ### ⚠️ 禁止行为
   - ❌ 禁止跳过步骤0可行性验证
   - ❌ 禁止因"简单需求"简化流程
   - ❌ 禁止自主判断后跳过澄清环节
   `,
       model: "sonnet"
   })
   ```

3. **等待子Agent完成，验证产物**：
   ```
   Glob({ pattern: "DOCS/{需求号}/需求设计/requirement.md" })
   Glob({ pattern: "DOCS/{需求号}/任务拆分/任务索引.md" })
   ```

4. **技能不可用时**：询问用户处理方式

   ```markdown
   AskUserQuestion({
     questions: [
       {
         header: "前置文档缺失",
         question: "需求号 {需求号} 的前置文档缺失，且 ai-prd-auto 技能不可用。前置文档用于后续编码步骤，缺失将导致流程无法继续。请选择处理方式：",
         multiSelect: false,
         options: [
           {
             label: "跳过该需求号",
             description: "跳过需求号 {需求号}，继续处理其他需求号"
           },
           {
             label: "暂停流程",
             description: "暂停流程，等待手动准备前置文档或安装 ai-prd-auto 技能"
           },
           {
             label: "取消流程",
             description: "终止本次自动化开发流程"
           }
         ]
       }
     ]
   })
   ```

5. **产物验证失败时**：询问用户处理方式

   ```markdown
   AskUserQuestion({
     questions: [
       {
         header: "产物验证失败",
         question: "需求号 {需求号} 的 ai-prd-auto 执行完成，但产物验证失败。缺失的文档将影响后续编码步骤。请选择处理方式：",
         multiSelect: false,
         options: [
           {
             label: "重新执行需求分析",
             description: "重新调用 ai-prd-auto 子Agent（最多重试2次）"
           },
           {
             label: "跳过该需求号",
             description: "跳过需求号 {需求号}，继续处理其他需求号"
           },
           {
             label: "暂停流程",
             description: "暂停流程，等待手动检查产物"
           }
         ]
       }
     ]
   })
   ```

**用户选择处理**：

| 用户选择 | 处理方式 |
|----------|----------|
| 重新执行需求分析 | 重新调用 ai-prd-auto（最多2次），完成后重新验证 |
| 跳过该需求号 | 记录到调度日志，跳过该需求号，处理下一个 |
| 暂停流程 | 输出提示信息，流程暂停，等待用户处理后重新触发 |
| 取消流程 | 输出取消信息，流程终止 |

**日志记录**：
```
[INFO] Step 0.5-自动补全：需求号 {需求号}
       - ai-prd-auto技能：✅ 可用 / ❌ 不可用
       - 调用子Agent：执行需求分析
       - 产物验证：✅ 通过 / ❌ 失败
       → 通过：进入Step 0.6
       → 失败：询问用户处理方式
```

---

**完成后动作**：
- 前置文档完整：立即进入 Step 0.6
- 已通过附件补全：进入 Step 0.6
- 已通过 ai-prd-auto 补全：进入 Step 0.6
- 用户选择跳过：处理下一个需求号或进入 Step 0.6（如果所有需求号都已处理）
- 用户选择暂停/取消：流程暂停或终止

---

**⚠️ Step 0.6: 子技能存在性验证（必须执行）**

**核心目的**：在流程开始前验证所有子技能文件是否存在，避免执行中途发现技能缺失导致流程中断。

**必须验证的子技能列表**：

| 步骤 | 子技能名称 | 技能文件路径 | 用途 |
|------|------------|--------------|------|
| Step 2 | ai-backend-dev-pro | `.claude/skills/ai-backend-dev-pro/SKILL.md` | 后端编码 |
| Step 3 | ai-frontend-dev-pro | `.claude/skills/ai-frontend-dev-pro/SKILL.md` | 前端编码 |
| Step 4 | ai-code-review-agent | `.claude/skills/ai-code-review-agent/SKILL.md` | 代码评审 |
| Step 5 | ai-automated-test-agent | `.claude/skills/ai-automated-test-agent/SKILL.md` | 自动化测试 |
| Step 6 | ai-git-push | `.claude/skills/ai-git-push/SKILL.md` | Git提交 |

**验证方法**：使用 Glob 工具检查每个技能文件路径是否存在。

```
Glob({
    pattern: ".claude/skills/{技能名称}/SKILL.md"
})
```

**验证结果处理**：

| 结果 | 处理方式 |
|------|----------|
| 所有技能存在 | ✅ 继续进入 Step 1 |
| 有技能缺失 | ⛔ **必须使用 AskUserQuestion 询问用户** |

**技能缺失询问流程**（使用 AskUserQuestion 工具）：

当检测到技能缺失时，对每个缺失的技能逐一询问用户：

```markdown
AskUserQuestion({
  questions: [
    {
      header: "技能缺失",
      question: "检测到子技能 {技能名称} 文件不存在（路径：.claude/skills/{技能名称}/SKILL.md）。该技能用于 {步骤名称}，缺失将影响流程完整性。请选择处理方式：",
      multiSelect: false,
      options: [
        {
          label: "跳过该步骤",
          description: "跳过 {步骤名称}，继续执行后续步骤（可能导致流程不完整）"
        },
        {
          label: "暂停流程",
          description: "暂停流程，等待安装技能后重新触发"
        },
        {
          label: "取消流程",
          description: "终止本次自动化开发流程"
        }
      ]
    }
  ]
})
```

**⚠️ 禁止的行为**：
- ❌ 检测到技能缺失后，自主决定跳过不询问用户
- ❌ 检测到技能缺失后，自主判断"简单任务不需要该技能"
- ❌ 检测到技能缺失后，自主用其他方式替代

**用户选择处理**：

| 用户选择 | 处理方式 |
|----------|----------|
| 跳过该步骤 | 记录缺失技能到调度日志，该步骤标记为 `skipped: missing_skill`，继续验证下一个技能 |
| 暂停流程 | 输出提示信息，流程暂停，等待用户安装技能后重新触发 |
| 取消流程 | 输出取消信息，流程终止 |

**完成后**：立即进入 Step 1

---

### Step 1: 创建 Worktree 和分支 + 复制DOCS文档

**⚠️ 重要：禁止使用 EnterWorktree 工具**

**分支检测**：`feature/{需求号}` 分支可能已由 `ai-prd-auto` 前置创建并推送。创建 worktree 前先检测：

```bash
# 1. 检测分支是否存在
LOCAL_BRANCH=$(git branch --list "feature/{需求号}" 2>/dev/null)
REMOTE_BRANCH=$(git branch -r --list "origin/feature/{需求号}" 2>/dev/null)

# 2a. 远程存在但本地不存在 → 先 fetch
if [ -z "$LOCAL_BRANCH" ] && [ -n "$REMOTE_BRANCH" ]; then
    git fetch origin "feature/{需求号}"
fi

# 2b. 分支已存在（本地或远程）→ 基于现有分支创建 worktree
if [ -n "$LOCAL_BRANCH" ] || [ -n "$REMOTE_BRANCH" ]; then
    git worktree add worktree-{需求号} "feature/{需求号}"
else
    # 2c. 分支不存在 → 创建新分支和 worktree（原逻辑）
    git worktree add worktree-{需求号} -b "feature/{需求号}" --no-track
fi

# 3. 验证创建结果
git worktree list
git -C worktree-{需求号} branch --show-current
```

**Step 1.5: 在 worktree 内创建 DOCS 目录结构并复制前置产出物**

> **前置分支场景**：若 `feature/{需求号}` 由 `ai-prd-auto` 前置创建并推送，worktree 中可能已包含 `DOCS/{需求号}/` 下的需求分析产物。本步骤的复制操作会将主工作区中可能新增的 DOCS（如 `ai-architecture-design` 产出的架构设计文档）覆盖同步到 worktree，确保包含所有最新产物。已存在的需求分析产物不会被重复提交。

```bash
# 创建 DOCS 目录结构（在 worktree 内）
mkdir -p worktree-{需求号}/DOCS/{需求号}/需求设计
mkdir -p worktree-{需求号}/DOCS/{需求号}/原型设计
mkdir -p worktree-{需求号}/DOCS/{需求号}/架构设计
mkdir -p worktree-{需求号}/DOCS/{需求号}/任务拆分
mkdir -p worktree-{需求号}/DOCS/{需求号}/后端编码
mkdir -p worktree-{需求号}/DOCS/{需求号}/前端编码
mkdir -p worktree-{需求号}/DOCS/{需求号}/代码评审
mkdir -p worktree-{需求号}/DOCS/{需求号}/自动化测试
mkdir -p worktree-{需求号}/DOCS/{需求号}/Git提交
```

**复制前置产出物到 worktree**：

```bash
# 复制需求设计文档
cp -r DOCS/{需求号}/需求设计/* worktree-{需求号}/DOCS/{需求号}/需求设计/

# 复制原型设计（支持两种路径）
# 方式1：原型设计作为需求设计子目录
if [ -d "DOCS/{需求号}/需求设计/prototype" ]; then
    cp -r DOCS/{需求号}/需求设计/prototype worktree-{需求号}/DOCS/{需求号}/需求设计/
fi
# 方式2：原型设计作为独立目录（当前规范）
if [ -d "DOCS/{需求号}/原型设计" ]; then
    mkdir -p worktree-{需求号}/DOCS/{需求号}/原型设计
    cp -r DOCS/{需求号}/原型设计/* worktree-{需求号}/DOCS/{需求号}/原型设计/
fi

# 复制架构设计文档（如果存在）
if [ -d "DOCS/{需求号}/架构设计" ]; then
    cp -r DOCS/{需求号}/架构设计/* worktree-{需求号}/DOCS/{需求号}/架构设计/
fi

# 复制任务拆分清单
cp -r DOCS/{需求号}/任务拆分/* worktree-{需求号}/DOCS/{需求号}/任务拆分/
```

**创建 sched_log.md 初始文件**：

使用 Write 工具创建 `worktree-{需求号}/DOCS/{需求号}/sched_log.md`。

**完成后**：
- 更新 `worktree-{需求号}/DOCS/{需求号}/sched_log.md` Step 1 状态为 success
- 立即进入 Step 2（后端编码）

---

## Phase 2: 编码实现

### Step 2: 后端编码（子Agent强制调用）

**⚠️ 必须通过子Agent调用 ai-backend-dev-pro 技能，禁止自主执行！**

**⚠️ 关键：子Agent从 worktree 内的 DOCS 目录读取已复制的需求设计文档**

```markdown
Agent({
    subagent_type: "general-purpose",
    description: "后端编码 - 需求号 {需求号}",
    prompt: `
## ⚠️ 强制执行指令

你正在作为 ai-auto-dev 的子 Agent 执行后端编码任务。

### 任务信息
- 需求号：{需求号}
- Worktree路径：worktree-{需求号}
- 任务类型：后端编码

### ⚠️ 技能执行要求（强制遵守）

**你必须严格执行以下技能文件定义的流程：**

1. 首先使用 Read 工具读取技能文件：
   - 文件路径：.claude/skills/ai-backend-dev-pro/SKILL.md

2. **严格按照技能文件中定义的步骤顺序执行**：
   - Step 0：准入检查
   - Step 1：获取任务（阅读项目知识库）
   - Step 2：编码实现
   - Step 3：验证测试
   - Step 4：修复循环（如需要）
   - Step 5：更新状态
   - Step 6：准出检查
   - **禁止跳过任何步骤**
   - **禁止自主简化流程**

3. 技能文件中引用的 references/workflow-guide.md 必须读取并执行

4. 技能文件中定义的准出标准必须全部满足

### ⚠️ 前置产出物路径（已复制到 worktree 内）
- 需求设计文档：worktree-{需求号}/DOCS/{需求号}/需求设计/requirement.md
- 原型设计目录：worktree-{需求号}/DOCS/{需求号}/需求设计/prototype/
- 架构设计文档：worktree-{需求号}/DOCS/{需求号}/架构设计/（如存在）
- 任务拆分清单：worktree-{需求号}/DOCS/{需求号}/任务拆分/

### 文档路径约定
- 调度日志：worktree-{需求号}/DOCS/{需求号}/sched_log.md
- 执行进度：worktree-{需求号}/DOCS/{需求号}/后端编码/exec_prog.md
- 代码路径：worktree-{需求号}/icis/icis-biz-main/

### 编译命令
mvn compile -f worktree-{需求号}/icis/pom.xml -DskipTests

### 完成后动作
1. 更新 worktree-{需求号}/DOCS/{需求号}/sched_log.md Step 2 状态为 success
2. 静默返回，不输出任何状态报告或总结
`,
    model: "sonnet"
})
```

**子Agent返回后**：
- 立即进入 Step 3（前端编码）

---

### Step 3: 前端编码（子Agent强制调用）

**⚠️ 必须通过子Agent调用 ai-frontend-dev-pro 技能，禁止自主执行！**

**⚠️ 关键：子Agent从 worktree 内的 DOCS 目录读取已复制的需求设计文档**

```markdown
Agent({
    subagent_type: "general-purpose",
    description: "前端编码 - 需求号 {需求号}",
    prompt: `
## ⚠️ 强制执行指令

你正在作为 ai-auto-dev 的子 Agent 执行前端编码任务。

### 任务信息
- 需求号：{需求号}
- Worktree路径：worktree-{需求号}
- 任务类型：前端编码

### ⚠️ 技能执行要求（强制遵守）

**你必须严格执行以下技能文件定义的流程：**

1. 首先使用 Read 工具读取技能文件：
   - 文件路径：.claude/skills/ai-frontend-dev-pro/SKILL.md

2. **严格按照技能文件中定义的步骤顺序执行**：
   - Step 0：准入检查
   - Step 1：获取任务（阅读项目知识库）
   - Step 2：编码实现
   - Step 3：验证测试
   - Step 4：修复循环（如需要）
   - Step 5：更新状态
   - Step 6：准出检查
   - **禁止跳过任何步骤**
   - **禁止自主简化流程**

3. 技能文件中引用的 references/workflow-guide.md 必须读取并执行

4. 技能文件中定义的准出标准必须全部满足

### ⚠️ 前置产出物路径（已复制到 worktree 内）
- 需求设计文档：worktree-{需求号}/DOCS/{需求号}/需求设计/requirement.md
- 原型设计目录：worktree-{需求号}/DOCS/{需求号}/需求设计/prototype/
- 架构设计文档：worktree-{需求号}/DOCS/{需求号}/架构设计/（如存在）
- 任务拆分清单：worktree-{需求号}/DOCS/{需求号}/任务拆分/

### 文档路径约定
- 调度日志：worktree-{需求号}/DOCS/{需求号}/sched_log.md
- 执行进度：worktree-{需求号}/DOCS/{需求号}/前端编码/exec_prog.md
- 代码路径：worktree-{需求号}/icis/icis-ui/

### 完成后动作
1. 更新 worktree-{需求号}/DOCS/{需求号}/sched_log.md Step 3 状态为 success
2. 静默返回，不输出任何状态报告或总结
`,
    model: "sonnet"
})
```

**子Agent返回后**：
- 立即进入 Step 4（代码评审）

---

## Phase 3: 质量保障

### Step 4: 代码评审（子Agent强制调用）

**⚠️ 必须通过子Agent调用 ai-code-review-agent 技能，禁止自主执行！**

```markdown
Agent({
    subagent_type: "general-purpose",
    description: "代码评审 - 需求号 {需求号}",
    prompt: `
## ⚠️ 强制执行指令

你正在作为 ai-auto-dev 的子 Agent 执行代码评审任务。

### 任务信息
- 需求号：{需求号}
- Worktree路径：worktree-{需求号}
- 任务类型：代码评审

### ⚠️ 技能执行要求（强制遵守）

**你必须严格执行以下技能文件定义的流程：**

1. 首先使用 Read 工具读取技能文件：
   - 文件路径：.claude/skills/ai-code-review-agent/SKILL.md

2. **严格按照技能文件中定义的步骤顺序执行**：
   - Stage 1：预处理（参数验证、TFS连接、分支差异计算）
   - Stage 2：规则加载（四层规则体系）
   - Stage 3：代码审查（多技术栈统一审查、四轮审查法）
   - Stage 4：结果聚合（问题去重、评分计算）
   - Stage 5：输出交付（报告生成、TFS上传、阻断判断）
   - **禁止跳过任何步骤**
   - **禁止自主简化流程**

3. 技能文件中引用的 step/*.md 文件必须按需读取并执行

4. 技能文件中定义的输出格式必须严格遵循

### ⚠️ 前置产出物路径（已复制到 worktree 内）
- 需求设计文档：worktree-{需求号}/DOCS/{需求号}/需求设计/requirement.md
- 架构设计文档：worktree-{需求号}/DOCS/{需求号}/架构设计/（如存在）

### 审查范围
- 后端代码：worktree-{需求号}/icis/icis-biz-main/
- 前端代码：worktree-{需求号}/icis/icis-ui/

### 文档路径约定
- 调度日志：worktree-{需求号}/DOCS/{需求号}/sched_log.md
- 执行进度：worktree-{需求号}/DOCS/{需求号}/代码评审/exec_prog.md
- 审查报告：worktree-{需求号}/DOCS/{需求号}/代码审查/审查报告_{日期}.md

### 完成后动作
1. 更新 worktree-{需求号}/DOCS/{需求号}/sched_log.md Step 4 状态为 success
2. 静默返回，不输出任何状态报告或总结
`,
    model: "sonnet"
})
```

**子Agent返回后**：
- 立即进入 Step 5（自动化测试）

---

### Step 5: 自动化测试（子Agent强制调用）

**⚠️ 必须通过子Agent调用 ai-automated-test-agent 技能，禁止自主执行！**

```markdown
Agent({
    subagent_type: "general-purpose",
    description: "自动化测试 - 需求号 {需求号}",
    prompt: `
## ⚠️ 强制执行指令

你正在作为 ai-auto-dev 的子 Agent 执行自动化测试任务。

### 任务信息
- 需求号：{需求号}
- Worktree路径：worktree-{需求号}
- 任务类型：自动化测试

### ⚠️ 技能执行要求（强制遵守）

**你必须严格执行以下技能文件定义的流程：**

1. 首先使用 Read 工具读取技能文件：
   - 文件路径：.claude/skills/ai-automated-test-agent/SKILL.md

2. **严格按照技能文件中定义的步骤顺序执行**：
   - Stage 1：前置产出物收集（读取需求设计/架构设计/代码审查结果）
   - Stage 2：测试用例设计（正常场景、异常场景、边界值）
   - Stage 3：测试代码生成（根据技术栈选择框架）
   - Stage 4：测试执行（单元测试、接口测试）
   - Stage 5：报告生成与交付（Bug分级、报告输出）
   - **禁止跳过任何步骤**
   - **禁止自主简化流程**

3. 技能文件中引用的 step/*.md 文件必须按需读取并执行

4. 技能文件中定义的输出格式必须严格遵循

### ⚠️ 前置产出物路径（已复制到 worktree 内）
- 需求设计：worktree-{需求号}/DOCS/{需求号}/需求设计/
- 架构设计：worktree-{需求号}/DOCS/{需求号}/架构设计/
- 代码审查：worktree-{需求号}/DOCS/{需求号}/代码审查/

### 测试范围
- 后端代码：worktree-{需求号}/icis/icis-biz-main/
- 前端代码：worktree-{需求号}/icis/icis-ui/

### 文档路径约定
- 调度日志：worktree-{需求号}/DOCS/{需求号}/sched_log.md
- 执行进度：worktree-{需求号}/DOCS/{需求号}/自动化测试/exec_prog.md
- 测试报告：worktree-{需求号}/DOCS/{需求号}/自动化测试/测试报告_{日期}.md

### 完成后动作
1. 更新 worktree-{需求号}/DOCS/{需求号}/sched_log.md Step 5 状态为 success
2. 静默返回，不输出任何状态报告或总结
`,
    model: "sonnet"
})
```

**子Agent返回后**：
- 立即进入 Step 6（Git提交）

---

## Phase 4: 交付与清理

### Step 6: Git提交（子Agent强制调用）

**⚠️ 必须通过子Agent调用 ai-git-push 技能，禁止自主执行！**

**⚠️ 关键：DOCS 目录已创建在 worktree 内，ai-git-push 子Agent执行 `git add -A` 时会自动包含代码和文档**

**⚠️ TFS 状态更新：ai-git-push 包含 Step 7/8 用于更新 TFS 子任务和需求状态，必须完整执行！**

```markdown
Agent({
    subagent_type: "general-purpose",
    description: "Git提交 - 需求号 {需求号}",
    prompt: `
## ⚠️ 强制执行指令

你正在作为 ai-auto-dev 的子 Agent 执行 Git 提交任务。

### 任务信息
- 需求号：{需求号}
- Worktree路径：worktree-{需求号}
- 任务类型：Git提交 + TFS状态更新

### ⚠️ 技能执行要求（强制遵守）

**你必须严格执行以下技能文件定义的流程：**

1. 首先使用 Read 工具读取技能文件：
   - 文件路径：.claude/skills/ai-git-push/SKILL.md

2. **严格按照技能文件中定义的步骤顺序执行（共8个步骤）**：
   - Step 0：项目检测与模式判断
   - Step 1：准入检查（检测 sched_log.md 所有步骤状态）
   - Step 2：工作区检查
   - Step 3：自动提交代码
   - Step 4：更新文档
   - Step 5：准出检查
   - Step 6：自动推送
   - **Step 7：更新子任务状态（推送成功后必须执行）**
   - **Step 8：更新需求状态（所有子任务已关闭后必须执行）**
   - **⛔ 禁止跳过 Step 7 和 Step 8！这两个步骤负责 TFS 状态同步**
   - **禁止跳过任何步骤**
   - **禁止自主简化流程**

3. **⚠️ TFS 状态更新说明**：
   - Step 7 会将所有子任务状态更新为"已关闭"
   - Step 8 会将需求状态更新为"已解决"
   - 这是流程完整性要求，跳过会导致 TFS 状态不一致

4. 技能文件中定义的静默返回模式必须遵守

### ⚠️ 文档路径约定
- 调度日志：worktree-{需求号}/DOCS/{需求号}/sched_log.md
- 代码和文档都在 worktree 内，执行 git add -A 会同时添加

### Git命令规范
- 使用 git -C worktree-{需求号} 参数
- 禁止使用 cd worktree-{需求号} && git ...

### 完成后动作
1. 更新 worktree-{需求号}/DOCS/{需求号}/sched_log.md Step 6 状态为 success
2. 静默返回，不输出任何状态报告或总结
`,
    model: "sonnet"
})
```

**子Agent返回后**：
- 立即进入 Step 7（清理前验证）

---

### Step 7: 清理前验证

**核心目的**：验证前置步骤完成状态，确保流程完整性可追溯。

执行内容：
1. 验证 Git 提交状态（读取 sched_log.md 检查 Step 6 状态）
2. 验证工作区状态（`git -C worktree-{需求号} status --porcelain`）
3. 使用 Edit 工具更新 sched_log.md Step 7 部分

**详细执行指令**：见 [step-execution.md](references/step-execution.md#step-7-清理前验证)

**完成后动作**：
- 验证通过：进入 Step 8
- 验证失败：跳过 Step 8，将 Step 8 状态设为 skipped

---

### Step 8: 清理 Worktree

**核心目的**：释放开发隔离环境，完成资源回收。

执行内容：
1. 执行清理命令（`git worktree remove worktree-{需求号} --force`）
2. 验证清理结果（`git worktree list`）
3. 使用 Edit 工具更新 sched_log.md Step 8 部分

**详细执行指令**：见 [step-execution.md](references/step-execution.md#step-8-清理-worktree)

**完成后动作**：
- 有其他需求号未处理：进入 Step 1 处理下一个
- 所有需求号已处理完毕：进入 Step 9

---

## Phase 5: 完成

### Step 9: 更新调度日志最终状态

**核心目的**：汇总执行结果，提供流程完成度全景视图。

执行内容：
1. 读取 sched_log.md 获取启动时间和各步骤状态
2. 计算统计数据（整体耗时、成功/失败/跳过步骤数）
3. 使用 Edit 工具更新流程完成状态部分

**详细执行指令**：见 [step-execution.md](references/step-execution.md#step-9-更新调度日志最终状态)

**完成后**：进入 Step 10

### Step 10: 生成执行汇总报告

生成汇总报告，包含各需求号完成状态、代码变更统计。

**完成后**：进入 Step 11

### Step 11: 输出工作总结（唯一终点）

这是整个流程的唯一终点，唯一允许向用户输出总结的步骤。

**输出格式**：见 [step-execution.md](references/step-execution.md#step-11-输出工作总结唯一终点)

---

## 调度日志模板

**路径**：`worktree-{需求号}/DOCS/{需求号}/sched_log.md`

**完整模板**：见 [sched_log-template.md](references/sched_log-template.md)

模板使用唯一占位符标记（如 `<!-- STEP7_BLOCK -->` 到 `<!-- STEP7_END -->`），便于 Edit 工具精确匹配。

**关键步骤字段**：

| 步骤 | 核心字段 | 更新时机 |
|------|----------|----------|
| Step 7 | 状态、验证项、验证结果、执行时间 | 清理前验证完成 |
| Step 8 | 状态、清理操作、清理结果、执行时间 | Worktree清理完成 |
| 流程完成状态 | 整体状态、整体耗时、成功/失败/跳过步骤 | Step 9 执行时 |

---

## 配置速查

| 配置键 | 默认值 | 说明 |
|--------|--------|------|
| MAX_CONCURRENT_TASKS | 3 | 最大并发数 |
| MAX_RETRY_COUNT | 3 | 最大重试次数 |
| RETRY_DELAY_SECONDS | 10 | 重试等待(秒) |

---

## 参考文档

| 文档 | 内容 |
|------|------|
| [config-guide.md](references/config-guide.md) | 配置文件详细说明 |
| [worktree-guide.md](references/worktree-guide.md) | Git Worktree 操作指南 |

---

## 与其他技能的协作关系

| 技能 | 关系 | 说明 |
|------|------|------|
| ai-prd-auto | ⚠️ **新增：按需调用** | Step 0.5 Phase 3 前置文档缺失时调用，自动补全需求设计文档 |
| ai-tfs-integration | ⚠️ **新增：按需调用** | Step 0.5 Phase 2 查询 TFS 需求附件，按需下载复制到 DOCS |
| ai-backend-dev-pro | 子Agent调用 | 由 ai-auto-dev 调度执行 |
| ai-frontend-dev-pro | 子Agent调用 | 由 ai-auto-dev 调度执行 |
| ai-code-review-agent | 子Agent调用 | 由 ai-auto-dev 调度执行 |
| ai-automated-test-agent | 子Agent调用 | 由 ai-auto-dev 调度执行 |
| ai-git-push | 子Agent调用 | 由 ai-auto-dev 调度执行 |
| ai-git-merge | 后续独立执行 | 在 ai-auto-dev 完成后独立执行 |

**⚠️ Step 0.5 新增协作说明**：
- ai-prd-auto：前置文档缺失且无附件时自动调用，确保流程不中断
- ai-tfs-integration：检查 TFS 需求附件，有附件时自动复制到 DOCS 目录

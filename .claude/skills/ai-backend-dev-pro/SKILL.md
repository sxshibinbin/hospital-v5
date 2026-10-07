---
name: ai-backend-dev-pro
description: |
  Java Spring Boot / AKSO 框架后端开发 Skill（简化流程版）。

  **必须触发**：用户要进行 Java 后端开发、接口实现、功能开发。

  触发关键词（包含以下任一即触发）：
  - "开发需求" + 数字：如"开发需求 1506090"、"帮我开发需求 1506090"
  - "实现需求" + 数字：如"实现需求 1506090"、"帮我实现需求"
  - "后端开发" / "Java 后端开发" / "Spring Boot 开发"

  **不触发**：前端 Vue/React、Python/Go/Node.js、纯 SQL 优化、Docker/K8s

  **⚠️ 静默返回**：此技能是 ai-auto-dev 的子Agent。完成后静默返回（只更新索引文件），不输出状态报告。主调度自动继续执行后续步骤。
keywords: [开发需求, 实现需求, 后端开发, Java开发, SpringBoot]
tags: [开发需求, 实现需求, 后端开发]
priority: 10
requires_tools: [Bash, Read, Edit, Write, Glob, Grep, AskUserQuestion]
requires_bins: [git, mvn, java]
metadata:
  author: lzw3
  version: 1.6.0
  changes: |
    - v1.6.0: 新增"最小改动原则"和"注释规则"章节，确保编码只做必要改动、每次改动必须有注释说明
    - v1.5.0: 新增 Step 5.5 更新TFS任务标签逻辑：通过任务名称判断后端任务，新增'AI-CODING'标签
    - v1.4.0: 新增 Step 3.5 启动验证环节，包含打包验证、启动验证、API响应检查，处理鉴权返回401/403的情况
---

# Java 后端开发 Skill (ai-backend-dev-pro)

## 概述

此 Skill 为后端工程师提供简化的 Java/Spring Boot/AKSO 开发流程，专注于：
1. **知识先行** - 编码前必须先阅读并理解项目知识库
2. **任务驱动** - 从任务拆分目录获取待开发任务，逐一完成
3. **循环修复** - 验证不通过时自动循环修复，直到满足准出标准
4. **动态规范** - 编码规范从项目知识库动态读取
5. **过程追踪** - 实时记录开发过程，同步更新任务状态
6. **进度反馈** - 每个步骤完成后主动输出标准化反馈

**子Agent身份说明**：

此技能通常作为 **ai-auto-dev** 的子Agent被调用，完成 Step 2（后端编码）任务。

**调用方式**：主调度通过 Agent 工具启动子Agent，子Agent自主读取此技能文件并执行。

- 完成后更新 sched_log.md 状态为 success → 子Agent静默返回
- 主调度收到子Agent返回后立即继续执行 Step 3（前端编码）
- 输出的"工作总结"是**中间状态报告**，不表示整体流程结束

## 执行流程

```
Step 0: 准入检查     → 认任务目录、Git分支、Worktree
   ↓
Step 1: 获取任务     → 阅读项目知识库 → 获取待开发任务
   ↓
Step 2: 编码实现     → 按任务要求实现代码
   ↓
Step 3: 验证测试     → 编译 + 测试 + TODO检查 + 漏改检查
   ↓ (失败) → Step 4: 修复循环 → 回到 Step 3
   ↓ (通过)
Step 3.5: 启动验证   → 打包 + 启动 + API响应检查
   ↓
Step 5: 更新状态     → 更新 exec_proc.md、任务索引
   ↓
Step 5.5: 更新标签   → 给TFS后端任务新增'AI-CODING'标签（新增）
   ↓ (有下一个任务) → 回到 Step 1
   ↓ (无)
Step 6: 准出检查     → 确认所有任务完成
```

## 目录结构

```
DOCS/
├── 项目知识库/                  # 项目整体知识（必须先阅读）
│   ├── 编码规范.md
│   ├── 技术栈说明.md
│   ├── 架构设计.md
│   ├── 业务领域.md
│   └── 测试配置.md
│
└── {需求号}/
    ├── 后端编码/exec_proc.md    # 过程记录
    ├── 任务拆分/
    │   ├── 任务索引.md          # 任务总览和进度追踪
    │   └── 任务{n}.md           # 独立任务文件
    └── 知识库/                   # 需求特定知识（补充阅读）
```

## Git 策略

- **分支命名**：`feature/{需求号}`
- **Worktree命名**：`worktree-{需求号}`
- **Worktree路径**：项目根目录下的 `worktree-{需求号}`（禁止使用 `.claude/worktrees/` 路径）

## ⛔ 安全执行原则（必须遵守）

> **⚠️ 重要警告：Claude Code 安全层会强制拦截以下命令模式！**
>
> **无论如何配置白名单，以下命令都会触发人工确认弹窗，阻断自动执行！**

### 禁止的命令模式

| 禁止模式 | 原因 | 替代方案 |
|----------|------|----------|
| `cd path && git ...` | 安全层强制拦截 | `git -C path ...` |
| `cd path && mvn ...` | 安全层强制拦截 | `mvn -f path/pom.xml ...` |
| 在 worktree 内执行 `git` | 安全层强制拦截 | 在根目录用 `git -C` |

### ✅ 正确命令示例

```bash
# ✅ 正确 - 使用 git -C 参数
git -C worktree-{需求号} status --porcelain
git -C worktree-{需求号} log --oneline -3

# ✅ 正确 - 使用 -f 参数编译
mvn compile -f worktree-{需求号}/icis/pom.xml -DskipTests

# ✅ 正确 - 使用绝对路径读取文件
Read worktree-{需求号}/icis/icis-biz-main/src/main/java/...

# ✅ 正确 - 使用 Glob 搜索 worktree 目录
Glob worktree-{需求号}/icis/**/*.java
```

### ⛔ 禁止命令示例（切勿执行）

以下命令会被安全层拦截，导致流程中断：

```bash
# ⛔ 禁止 - 组合命令（安全层拦截）
cd worktree-{需求号} && git status
cd worktree-{需求号} && mvn compile

# ⛔ 禁止 - EnterWorktree 工具（会创建错误路径）
# EnterWorktree 工具会在 .claude/worktrees/ 下创建新 worktree
```

## 执行步骤概要

| 步骤 | 目标 | 详情参考 |
|------|------|----------|
| Step 0 | 准入检查 | [workflow-guide.md](references/workflow-guide.md#step-0-准入检查) |
| Step 1 | 获取任务（含知识库阅读） | [workflow-guide.md](references/workflow-guide.md#step-1-获取任务) |
| Step 2 | 编码实现 | [workflow-guide.md](references/workflow-guide.md#step-2-编码实现) |
| Step 3 | 验证测试 | [workflow-guide.md](references/workflow-guide.md#step-3-验证测试) |
| Step 3.5 | 启动验证 | [workflow-guide.md](references/workflow-guide.md#step-35-启动验证新增) |
| Step 4 | 修复循环 | [workflow-guide.md](references/workflow-guide.md#step-4-修复循环) |
| Step 5 | 更新状态 | [workflow-guide.md](references/workflow-guide.md#step-5-更新状态) |
| Step 5.5 | **更新TFS任务标签（新增）** | [workflow-guide.md](references/workflow-guide.md#step-55-更新tfs任务标签新增) |
| Step 6 | 准出检查 | [workflow-guide.md](references/workflow-guide.md#step-6-准出检查) |

**详细执行步骤请查阅**：[references/workflow-guide.md](references/workflow-guide.md)

## 反馈机制

每个步骤完成后必须输出标准化 `<FEEDBACK>` JSON 格式，供总调度技能追踪进度。

**反馈格式详情请查阅**：[references/feedback-spec.md](references/feedback-spec.md)

## 模板文件

- 过程记录模板：[templates/exec_proc-template.md](templates/exec_proc-template.md)
- 任务索引模板：[templates/task-index-template.md](templates/task-index-template.md)

## 准入准出标准

**准入**：
- 任务拆分目录有待开发任务
- Git 分支和 Worktree 配置正确

**准出**：
- 所有任务已完成
- 编译通过
- 测试通过
- **打包成功**
- **启动成功（服务能运行）**
- **API响应正常（200/401/403）**
- 无 TODO 遗留
- 无漏改

## 检查清单

### 准入阶段 (Step 0)
- [ ] 需求号已识别
- [ ] Git 分支正确
- [ ] Worktree 正确
- [ ] 任务拆分目录有待开发任务
- [ ] 反馈输出已执行

### 开发阶段 (Step 1-5)
- [ ] 项目知识库已阅读理解
- [ ] 需求知识库已补充阅读
- [ ] 任务详情已读取
- [ ] **最小改动原则已遵循（只改必要的代码）**
- [ ] **改动注释已添加（每次改动都有注释说明）**
- [ ] **未做未经请求的优化**
- [ ] 代码实现遵循规范
- [ ] 编译验证通过
- [ ] 测试验证通过
- [ ] 打包验证通过
- [ ] 启动验证通过
- [ ] API响应检查通过
- [ ] 无 TODO 遗留
- [ ] 无漏改
- [ ] exec_proc.md 已更新
- [ ] 任务索引已更新
- [ ] 反馈输出已执行

### 标签更新阶段 (Step 5.5)
- [ ] 任务类型判定已执行
- [ ] 后端任务 TFS ID 已获取
- [ ] AI-CODING 标签已添加（后端任务）
- [ ] 标签更新记录已写入 exec_proc.md
- [ ] 反馈输出已执行

### 准出阶段 (Step 6)
- [ ] 所有任务已完成
- [ ] 最终验证通过
- [ ] 启动验证通过
- [ ] TFS标签更新完成
- [ ] 任务索引整体状态已更新为「开发完成」
- [ ] 最终反馈输出已执行

## 完成索引记录（静默返回机制）

**⚠️ 重要变更：不再输出状态报告，只做索引记录**

为避免干扰主调度流程，子技能完成后**静默返回**，只更新索引文件：

### 完成时动作

1. 更新 `DOCS/{需求号}/后端编码/exec_proc.md` 状态为"完成"
2. 更新 `DOCS/{需求号}/sched_log.md` Step 2 状态为 success
3. **直接返回，不输出任何总结报告**

### 禁止输出内容

| 禁止输出 | 原因 |
|----------|------|
| ❌ 状态报告框 | 会干扰主调度自动流程 |
| ❌ `<FEEDBACK>` 标签 | 会被误识别为流程终点 |
| ❌ "工作总结"格式 | 会被误认为流程完成 |
| ❌ "后续建议" | 会触发用户交互 |

### 正确返回方式

```markdown
# DOCS/{需求号}/sched_log.md 更新示例

### Step 2: 后端编码
- **状态**：success
- **调度方式**：Skill调用
- **完成时间**：{时间}
- **新增文件**：{数量}个
```

**返回后主调度自动继续执行 Step 3 前端编码，无需任何信号。**

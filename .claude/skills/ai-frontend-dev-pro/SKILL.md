---
name: ai-frontend-dev-pro
description: "卫宁健康多前端技术栈自适应编码执行 Agent Skill。通过需求号自动识别前端技术栈（Vue 2/3 + Spark、HTML、TypeScript、快开框架 RDF），根据需求及接口设计自适应生成前端代码，包含页面布局、业务组件、路由配置、API封装、表单校验、列表展示、弹窗交互、样式适配。统一医疗后台系统 UI 规范（WinDesign），适配各类医疗业务场景，代码可直接部署使用。

**必须触发**（包含以下任一即触发）：
- '前端开发' + 数字/需求：如'前端开发需求 1506090'、'开发前端页面'
- '实现前端功能'、'开发页面'、'写组件'、Vue/前端/页面/组件相关需求
- Vue2 迁移 Vue3、前端代码重构
- '快开框架' + 开发/实现：如'用快开框架开发页面'
- 'RDF开发'、'pageCode' + 数字/名称
- 技术术语：Controller、Service、win-design、w-button、w-form、w-table、Spark

tags: [前端开发, Vue, Spark, RDF, 自动开发]
keywords: [前端开发, ai-frontend-dev-pro, Vue, Spark, RDF, pageCode, 快开框架]
metadata:
  author: 周翔
  version: 1.2.1
---

# 卫宁前端编码 Agent Skill （ai-frontend-dev-pro）

> **定位**：多前端技术栈自适应编码执行 Agent，从需求分析到代码落地一站式完成。
>
> **核心职责**：自动识别前端技术栈，根据需求及接口设计，自适应生成前端代码，统一医疗后台系统 UI 规范，适配各类医疗业务场景，代码可直接部署使用。

## 概述

此 Skill 为前端工程师提供完整的前端开发流程，专注于：
1. **技术栈自适应** - 自动识别 Vue 2/3 + Spark、RDF、HTML 等技术栈
2. **需求驱动** - 从 TFS 工作项或 PRD 文档获取需求
3. **知识先行** - 编码前先阅读项目知识库理解技术规范
4. **循环验证** - 代码生成后自动验证，失败自动修复
5. **进度反馈** - 每个步骤完成后主动输出标准化反馈
6. **过程追踪** - 实时记录开发过程，同步更新任务状态

**子Agent身份说明**：

此技能通常作为 **ai-auto-dev** 的子Agent被调用，完成 Step 3（前端编码）任务。

**调用方式**：主调度通过 Agent 工具启动子Agent，子Agent自主读取此技能文件并执行。

- 完成后更新 sched_log.md 状态为 success → 子Agent静默返回
- 主调度收到子Agent返回后立即继续执行 Step 4（代码审查）
- 输出的"工作总结"是**中间状态报告**，不表示整体流程结束

## 技术栈覆盖

| 技术栈 | 框架/库 | 组件库 | 适用场景 |
|--------|---------|--------|----------|
| **Vue 2 + Spark** | Vue 2.6+, Options API | win-design@^2.6 | 传统医疗后台系统 |
| **Vue 3 + Spark** | Vue 3.3+, Composition API | win-design-next | 新一代医疗系统（WiNEX） |
| **HTML 静态原型** | HTML5 + CSS3 | WinDesign CSS | 原型设计、快速验证 |
| **快开框架 RDF** | TypeScript + XML 配置 | pango-framework | 低代码快速开发 |
| **TypeScript 纯模块** | TypeScript 5.0+ | - | 类型定义、工具函数、API 接口 |

## 执行流程

```
Step 0: 准入检查     → 确认任务目录、Git分支、Worktree
   ↓
Step 1: 获取任务     → 阅读项目知识库 → 获取待开发任务
   ↓
Step 2: 编码实现     → 按任务要求实现代码
   ↓
Step 3: 验证测试     → 编译 + 测试 + TODO检查 + 漏改检查
   ↓ (失败) → Step 4: 修复循环 → 回到 Step 3
   ↓ (通过)
Step 5: 更新状态     → 更新 exec_proc.md、任务索引
   ↓
Step 5.5: 更新标签   → 给TFS前端任务新增'AI-CODING'标签（新增）
   ↓ (有下一个任务) → 回到 Step 1
   ↓ (无)
Step 6: 准出检查     → 确认所有任务完成
```

## 目录结构

```
DOCS/
├── 项目知识库/                  # 项目整体知识（必须先阅读）
│   ├── tech_stack.md            # 技术栈说明
│   └── coding_standards.md      # 编码规范
│
└── {需求号}/
    ├── 需求设计/
    │   └── requirement.md       # 需求文档
    ├── 前端编码/
    │   ├── exec_prog.md         # 前端执行进度记录
    │   ├── impl_plan.md         # 实施计划（可选）
    │   └── code_changes.md      # 代码变更记录（可选）
    └── 任务拆解/
        ├── 任务索引.md         # 任务列表
        └── 任务{n}.md           # 独立任务文件
```

## ⛔ 安全执行原则（必须遵守）

> **⚠️ 重要警告：Claude Code 安全层会强制拦截以下命令模式！**
>
> **无论如何配置白名单，以下命令都会触发人工确认弹窗，阻断自动执行！**

### 禁止的命令模式

| 禁止模式 | 原因 | 替代方案 |
|----------|------|----------|
| `cd path && cmd` | 安全层强制拦截 | 使用绝对路径或工具参数 |
| `cd path && npm ...` | 安全层强制拦截 | 在 package.json 目录执行 |
| `cd path && git ...` | 安全层强制拦截 | `git -C path ...` |
| `cmd1 && cmd2` | 安全层强制拦截 | 分开执行，各自独立调用 |
| `cmd1 ; cmd2` | 安全层强制拦截 | 分开执行，各自独立调用 |
| `cmd1 | cmd2` | 安全层强制拦截 | 分开执行，各自独立调用 |

### ✅ 正确命令示例

```bash
# ✅ 正确 - 使用 git -C 参数
git -C worktree-{需求号} status --porcelain
git -C worktree-{需求号} log --oneline -3

# ✅ 正确 - npm 命令在指定目录执行（使用绝对路径）
npm run build --prefix worktree-{需求号}/icis/icis-ui
npm run lint --prefix worktree-{需求号}/icis/icis-ui
npm run fix --prefix worktree-{需求号}/icis/icis-ui

# ✅ 正确 - 使用绝对路径读取文件
Read worktree-{需求号}/icis/icis-ui/src/views/...

# ✅ 正确 - 使用 Glob 搜索前端文件
Glob worktree-{需求号}/icis/icis-ui/src/**/*.vue
Glob worktree-{需求号}/icis/icis-ui/src/**/*.ts

# ✅ 正确 - 单独执行命令（不组合）
# 第一条命令
npm run lint --prefix worktree-{需求号}/icis/icis-ui
# 第二条命令（单独调用）
npm run build --prefix worktree-{需求号}/icis/icis-ui
```

### ⛔ 禁止命令示例（切勿执行）

以下命令会被安全层拦截，导致流程中断：

```bash
# ⛔ 禁止 - 组合命令（安全层拦截）
cd worktree-{需求号}/icis/icis-ui && npm run build
cd worktree-{需求号} && git status

# ⛔ 禁止 - 管道连接符
npm run lint && npm run build
git add -A && git commit -m "msg"

# ⛔ 禁止 - EnterWorktree 工具（会创建错误路径）
# EnterWorktree 工具会在 .claude/worktrees/ 下创建新 worktree
```

## Git 策略

- **分支命名**：`feature/{需求号}`（新功能）或 `bugfix/{需求号}`（Bug修复）
- **Worktree命名**：`worktree-{需求号}`
- **多模块项目**：先识别涉及子模块，再在各子模块创建分支
- 自动核实并创建

## 执行步骤概要

| 步骤 | 目标 | 详情参考 |
|------|------|----------|
|------|------|----------|
| Step 0 | 准入检查 | [workflow-guide.md](references/workflow-guide.md#step-0-准入检查) |
| Step 1 | 获取任务（含知识库阅读） | [workflow-guide.md](references/workflow-guide.md#step-1-获取任务) |
| Step 2 | 编码实现 | [workflow-guide.md](references/workflow-guide.md#step-2-编码实现) |
| Step 3 | 验证测试 | [workflow-guide.md](references/workflow-guide.md#step-3-验证测试) |
| Step 3.5 | **启动验证（新增）** | [workflow-guide.md](references/workflow-guide.md#step-35-启动验证新增) |
| Step 4 | 修复循环 | [workflow-guide.md](references/workflow-guide.md#step-4-修复循环) |
| Step 5 | 更新状态 | [workflow-guide.md](references/workflow-guide.md#step-5-更新状态) |
| Step 5.5 | **更新TFS任务标签（新增）** | [workflow-guide.md](references/workflow-guide.md#step-55-更新tfs任务标签新增)|
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
- 所有代码已实现
- 类型检查通过
- Lint 检查通过
- 构建通过
- **开发服务器启动成功（新增）**
- **页面非白屏（新增）**
- 无硬编码文案
- 文档输出完整

## 检查清单

### 准入阶段 (Step 0)
- [ ] 需求来源已识别
- [ ] 技术栈已正确识别
- [ ] 组件库版本已确认
- [ ] 反馈输出已执行

### 开发阶段 (Step 1-5)
- [ ] 项目知识库已阅读理解
- [ ] 需求分析完成
- [ ] 实施计划已生成
- [ ] 用户已确认计划
- [ ] 开发分支已创建
- [ ] 使用 `<script setup lang="ts">`
- [ ] 从 `spark` 导入 API
- [ ] 使用 win-design 组件（`<w-*>`）
- [ ] TypeScript 类型完整
- [ ] 使用 i18n 多语言
- [ ] 类型检查通过
- [ ] Lint 检查通过
- [ ] 构建通过
- [ ] **开发服务器启动成功（新增）**
- [ ] **页面非白屏（新增）**
- [ ] **新增路由可访问（新增）**
- [ ] 修改记录已保存
- [ ] 执行进度已更新
- [ ] 反馈输出已执行

### 准出阶段 (Step 6)
- [ ] 所有任务已完成
- [ ] 最终验证通过
- [ ] **启动验证通过（新增）**
- [ ] 任务索引整体状态已更新为「开发完成」
- [ ] TFS 上传完成（如有工作项ID）
- [ ] AI-FRCODING 标签已添加
- [ ] 最终反馈输出已执行

## 复杂场景路由表

识别到以下场景时，加载对应的 reference 文档：

| 触发条件 | 加载 Reference | 内容 |
|----------|---------------|------|
| 需要详细技术栈规范 | `references/tech-standards.md` | Vue 2/3 + Spark、RDF、HTML 技术规范 |
| 动态表单、跨字段校验、分步表单 | `references/form-patterns.md` | 表单高级模式、代码模板 |
| 服务端分页、行选择、树形表格 | `references/table-patterns.md` | 表格高级模式、代码模板 |
| 远程搜索、多选、自定义模板 | `references/select-patterns.md` | 选择器高级模式 |
| 登录页、列表页、表单页、详情页 | `references/page-patterns.md` | 页面级模式与完整模板 |
| WinDesign 组件详细用法 | `references/win-design-components.md` | 组件 API 与最佳实践 |
| Spark 框架 API 详解 | `references/spark-api.md` | 响应式、状态管理、HTTP、工具函数 |
| 快开框架 RDF 开发 | `references/rdf-development.md` | XML 配置、TypeScript 控制类 |
| Vue 2 到 Vue 3 迁移 | `references/vue3-migration.md` | 迁移映射、场景示例、审计模板 |

## 工作总结

**完成所有任务后必须输出工作总结**：

```markdown
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 本次工作总结
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## ✅ 已完成的工作

### 需求信息
- **需求号**: {需求号}
- **需求标题**: {需求标题}
- **需求来源**: TFS / PRD文档 / 用户描述

### 技术栈
- **识别结果**: {技术栈}
- **组件库**: {组件库}
- **代码风格**: {代码风格}

### 开发分支
- **分支名称**: feature/{需求号}
- **涉及子模块**: {子模块列表}

### 代码变更
| 类型 | 文件数 | 说明 |
|------|--------|------|
| 新增 | {数量} | {简要说明} |
| 修改 | {数量} | {简要说明} |

### 功能实现
- [x] {功能点1}
- [x] {功能点2}

### 验证结果
- [x] 类型检查通过
- [x] Lint 检查通过
- [x] 构建通过

### 文档输出
- 实施计划: DOCS/{需求号}/任务拆解/task_list.md
- 修改记录: DOCS/{需求号}/前端编码/code_changes.md
- 执行进度: DOCS/{需求号}/前端编码/exec_prog.md
- TFS 上传: {已上传/跳过}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 后续建议:
1. 代码提交: 说"提交代码"、"提交并同步"触发 ai-git-merge 技能
2. Bug 修复: 如发现问题，请新开对话处理
3. 代码评审: 可使用 tfs-pr-skill 进行代码评审
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 参考文件

当需要详细信息时，请查阅以下参考文件：

| 文件 | 说明 |
|------|------|
| `references/workflow-guide.md` | 详细执行步骤（Step 0-10） |
| `references/feedback-spec.md` | 反馈机制规范 |
| `references/tech-standards.md` | 技术栈规范（Vue 2/3 + Spark、RDF、HTML） |
| `references/spark-api.md` | Spark 框架 API 详细文档 |
| `references/win-design-components.md` | WinDesign 组件库使用规范 |
| `references/form-patterns.md` | 表单高级模式与代码模板 |
| `references/table-patterns.md` | 表格高级模式与代码模板 |
| `references/select-patterns.md` | 选择器高级模式 |
| `references/page-patterns.md` | 页面级模式与完整模板 |
| `references/rdf-development.md` | 快开框架 RDF 开发指南 |
| `references/vue3-migration.md` | Vue 2 到 Vue 3 迁移规则 |

---
name: ai-code-review-agent
description: 代码规范审查Agent - 多技术栈代码审查、分层规则体系、TFS集成、阻断机制
tags: [review, code-quality, security, medical-compliance, multi-tech-stack]
allowed-tools: Bash(git:*), Read, Write, mcp__tfs-mcp__*
output_format: json_only
keywords: [代码审查, ai-code-review-agent, 规范审查, 安全审查, 代码质量, 医疗合规]
metadata:
  author: AI事业部
  version: 1.0.0
---

## Skill名称：ai-code-review-agent

## 功能描述
多Agent编排体系中的代码规范审查Agent，支持八大技术栈、四层规则体系、五维度审查、TFS集成与阻断机制。

## 核心能力
- **多技术栈支持**: Java、TypeScript、Rust、Vue3、C#、HTML、SQL、Python
- **四层规则体系**: 通用规则 → 医疗规则 → 产品线规则 → 项目规则
- **五维度审查**: 安全性、可维护性、性能、规范性、医疗合规
- **TFS集成**: 工作项关联、附件上传、状态回写、评论添加、AI-REVIEWED标签自动打标
- **阻断机制**: 基于阈值的自动阻断，支持产品线级别配置
- **自动修复**: 支持Java/Vue/SQL技术栈的7种规则自动修复，最大3轮回归审查

## 触发关键词
- 代码审查、代码规范审查、code-review-agent
- 审查代码、代码检查、规范检查
- /code-review、/review

## ⛔ 安全执行原则（必须遵守）

> **⚠️ 重要警告：Claude Code 安全层会强制拦截以下命令模式！**
>
> **无论如何配置白名单，以下命令都会触发人工确认弹窗，阻断自动执行！**

### 禁止的命令模式

| 禁止模式 | 原因 | 替代方案 |
|----------|------|----------|
| `cd path && cmd` | 安全层强制拦截 | 使用绝对路径或工具参数 |
| `cd path && git ...` | 安全层强制拦截 | `git -C path ...` |
| `cmd1 && cmd2` | 安全层强制拦截 | 分开执行，各自独立调用 |
| `cmd1 ; cmd2` | 安全层强制拦截 | 分开执行，各自独立调用 |
| `cmd1 | cmd2` | 安全层强制拦截 | 分开执行，各自独立调用 |

### ✅ 正确命令示例

```bash
# ✅ 正确 - 使用 git -C 参数
git -C worktree-{需求号} status --porcelain
git -C worktree-{需求号} log --oneline -3
git -C worktree-{需求号} diff main...feature/{需求号}

# ✅ 正确 - 使用绝对路径读取文件
Read worktree-{需求号}/icis/icis-biz-main/src/main/java/...

# ✅ 正确 - 使用 Glob 搜索代码文件
Glob worktree-{需求号}/icis/**/*.java
Glob worktree-{需求号}/icis/**/*.{vue,ts,js}

# ✅ 正确 - 单独执行命令（不组合）
# 第一条命令
git -C worktree-{需求号} status --porcelain
# 第二条命令（单独调用）
git -C worktree-{需求号} diff --stat
```

### ⛔ 禁止命令示例（切勿执行）

以下命令会被安全层拦截，导致流程中断：

```bash
# ⛔ 禁止 - 组合命令（安全层拦截）
cd worktree-{需求号} && git status
cd worktree-{需求号} && git diff

# ⛔ 禁止 - 管道连接符
git status && git diff
git add -A && git commit -m "msg"

# ⛔ 禁止 - EnterWorktree 工具（会创建错误路径）
# EnterWorktree 工具会在 .claude/worktrees/ 下创建新 worktree
```

## 输入要求

### 必需参数
| 参数名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| task_id | string | 任务唯一标识 | REVIEW-20260515-001 |
| work_item_id | integer | TFS工作项ID | 1500229 |
| product_line | string | 产品线名称 | AI-MY |
| project_name | string | 项目名称 | winning-mmop-winexmy |
| repository_url | string | 代码仓库地址 | https://tfs.winning.com/... |
| source_branch | string | 源分支名称 | feature/user-auth |
| target_branch | string | 目标分支名称 | main |
| tech_stack_tags | array | 技术栈标签 | ["java", "vue"] |
| scan_mode | string | 扫描模式 | initial/incremental |
| scan_type | string | 扫描类型 | full/security/quality |

### 可选参数
| 参数名 | 类型 | 说明 | 默认值 |
|--------|------|------|--------|
| collection | string | TFS集合名称 | 自动检测 |
| changed_files | array | 指定扫描文件 | 全量扫描 |
| exclude_patterns | array | 排除文件模式 | ["**/test/**"] |

## 流水线执行流程

### Stage 1: 预处理
@step/01-preprocess.md
- 参数验证与环境检查
- TFS连接与工作项获取
- 分支差异计算

### Stage 2: 规则加载
@step/02-load-rules.md
- 四层规则体系加载
- 规则合并与优先级处理
- 技术栈规则过滤

### Stage 3: 代码审查
@step/03-review.md
- 多技术栈统一审查
- 四轮审查法执行
- 问题收集与分类

### Stage 4: 结果聚合
@step/04-aggregate.md
- 问题去重与合并
- 评分计算
- 统计摘要生成

### Stage 5: 输出交付
@step/05-output.md
- 报告生成（Markdown/JSON/CSV）
- TFS附件上传
- 阻断判断与状态回写
- 添加 AI-REVIEWED 标签（审查完成标记）
- 审查有残留 warning 时添加 AI-VERIFY-WARN 标签

### Stage 6: 自动修复
@step/06-auto-fix.md
- 轮次检查（最大3轮）
- 修复可行性评估（仅 critical + warning）
- 执行自动修复
- 修复验证与回归审查

## 输出格式
@references/output-schema.json

### 输出示例
```json
{
  "task_id": "REVIEW-20260515-001",
  "work_item_id": 1500229,
  "status": "fix_failed",
  "review_round": 3,
  "summary": {
    "total_issues": 15,
    "critical": 0,
    "warning": 2,
    "info": 13
  },
  "fix_summary": {
    "rounds_executed": 3,
    "total_fixed": 13,
    "remaining_critical": 0,
    "remaining_warning": 2,
    "unfixable_reason": "规则 COMMON-SEC-001 需人工确认SQL重构"
  },
  "report_files": {
    "local_path": "DOCS/1500229/代码审查/审查报告_20260515.md",
    "fix_report_path": "DOCS/1500229/代码审查/修复报告_20260515.md",
    "tfs_attachment_id": 12345
  },
  "next_action": "manual_fix_required",
  "completed_at": "2026-05-15T16:30:00Z"
}
```

## 协作协议
- 输入协议：@references/input-schema.json
- 输出协议：@references/output-schema.json
- 阻断配置：@references/block-config.json

## 规则体系

### Level 1: 通用编码规则
@rules/common/common-rules.json
- 安全漏洞检查（SQL注入、XSS、敏感信息暴露）
- 代码质量检查（空catch块、N+1查询、命名规范）

### Level 2: 医疗通用规则
@rules/medical/medical-rules.json
- 患者数据脱敏
- 敏感数据加密
- 审计日志规范

### Level 3: 产品线规则
@rules/product/{product_line}/{product_line}-rules.json
- AI-MY: API规范、移动端适配
- AI重症: 实时性检查、告警机制
- 病历质控: 数据完整性、质控规则
- CDSS: 决策逻辑、知识库集成
- 医保控费: 费用计算、合规检查

### Level 4: 项目规则
@rules/project/{project_name}/project-rules.json
- 项目特定规范
- 自定义检查规则

## 报告模板
- Markdown报告：@templates/report-template.md
- JSON报告模板：@templates/report-template.json.tmpl
- CSV清单：@templates/issue-list-template.csv

## 执行进度文档

运行时生成，路径：`DOCS/{work_item_id}/代码审查/exec_prog.md`

**更新频率**: 每10分钟自动更新

**记录内容**:
- 当前执行状态和阶段进度
- 文件扫描统计
- 规则命中统计
- 问题汇总（按级别、类型）
- 质量评分变化
- 执行日志和预估信息

模板文件：@exec_prog.md

## 与其他Agent协作

### 前置Agent
- PRD解析Agent: 接收需求上下文
- 架构设计Agent: 获取架构约束
- 编码Agent: 审查代码产出

### 后续Agent
- 自动化测试Agent: 触发测试流水线
- 交付Git运维Agent: 执行代码合并

## 使用示例

### 示例1: 基本审查
```
审查工作项1500229的代码，产品线AI-MY，技术栈java和vue
```

### 示例2: 安全专项审查
```
对工作项1500229进行安全审查，只扫描变更文件
```

### 示例3: 完整参数
```json
{
  "task_id": "REVIEW-20260515-001",
  "work_item_id": 1500229,
  "product_line": "AI-MY",
  "project_name": "winning-mmop-winexmy",
  "repository_url": "https://tfs.winning.com/WINNING-6.0/MY/_git/winning-mmop-winexmy",
  "source_branch": "feature/user-auth",
  "target_branch": "main",
  "tech_stack_tags": ["java", "vue"],
  "scan_mode": "incremental",
  "scan_type": "full"
}
```

## 错误处理

| 错误类型 | 处理方式 | 状态码 |
|----------|----------|--------|
| 参数缺失 | 返回错误信息，要求补充 | 400 |
| TFS连接失败 | 重试3次后返回错误 | 503 |
| 规则加载失败 | 使用默认规则继续 | 200 |
| 审查超时 | 返回部分结果，标记未完成 | 408 |

## 注意事项
1. 首次使用需配置TFS访问权限
2. 大型仓库建议使用incremental模式
3. 阻断阈值可通过block-config.json调整
4. 自定义规则需符合规则JSON Schema
5. 审查完成后必须为 TFS 工作项添加 `AI-REVIEWED` 标签（过程标签，系统自动添加），标记代码审查已完成
6. 审查通过但有残留 warning 时，同时添加 `AI-VERIFY-WARN` 标签
7. `AI-REVIEWED` 与 `AI-CODING` 形成阶段配对：编码完成→审查完成

## 版本历史
- v1.2.0: 新增 TFS 标签 AI-REVIEWED + AI-VERIFY-WARN，审查完成后自动打标
- v1.1.0: 新增 Stage 6 自动修复，支持 Java/Vue/SQL 共7种规则自动修复，最大3轮回归审查
- v1.0.0: 初始版本，支持八大技术栈、四层规则体系

## 修复配置
- 修复配置：@references/fix-config.json
- 修复规则注册表：@fix-engines/fix-registry.json
- Java修复引擎：@fix-engines/java-fix-engine.md
- Vue修复引擎：@fix-engines/vue-fix-engine.md
- SQL修复引擎：@fix-engines/sql-fix-engine.md
- 修复报告模板：@templates/fix-report-template.md

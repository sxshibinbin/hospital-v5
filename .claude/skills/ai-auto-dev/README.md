# ai-auto-dev

AI医疗事业部多Agent编排总调度中枢 - 多需求并行自动开发的完整解决方案。

## 核心能力

- **多任务并行调度**：支持多个需求号同时处理，并发上限可配置
- **Git Worktree 隔离**：每个需求独立worktree，分支管理清晰
- **步骤监控与重试**：等待返回 + 定时轮询，断点续传机制
- **过程文档追踪**：实时记录执行状态，支持中断恢复
- **全自动执行**：Bypass模式，无用户交互

## 流程结构

```
         ┌── 后端编码 ──→ 代码评审 ──┐
需求号 ──┤                          ├──→ 自动化测试 ──→ Git提交
         └── 前端编码 ──→ 代码评审 ──┘
```

## 使用方式

```bash
# 单需求号
ai-auto-dev REQ-001

# 多需求号并行
ai-auto-dev REQ-001,REQ-002,REQ-003
```

## 目录结构

```
skills/ai-auto-dev/
├── SKILL.md              # 技能定义（核心流程）
├── README.md             # 本文件
├── config.env            # 配置模板
├── references/           # 详细参考文档
│   ├── config-guide.md         # 配置详解
│   ├── worktree-guide.md       # Worktree操作
│   ├── retry-mechanism.md      # 重试机制
│   └── bypass-strategies.md    # Bypass策略
├── templates/            # 过程文档模板
│   ├── exec_prog_template.md
│   └── sched_log_template.md
└── scripts/              # 辅助脚本
    ├── init-worktree.sh
    ├── check-status.sh
    └── cleanup-worktree.sh

# 运行时目录（在项目根目录下）
{项目根目录}/DOCS/
├── config.env            # 项目配置
├── 项目知识库/           # 技术栈、构建命令
└── {需求号}/             # 过程文档
```

## 子Agent

| 子Agent | 职责 |
|---------|------|
| backend-coder | 后端代码编写 |
| frontend-coder | 前端代码编写 |
| code-reviewer | 代码质量检查 |
| auto-tester | 自动化测试 |
| git-committer | Git提交 |

## 配置

详见 `config.env` 和 `references/config-guide.md`

## 依赖

- Git（worktree管理）
- 子Agent技能